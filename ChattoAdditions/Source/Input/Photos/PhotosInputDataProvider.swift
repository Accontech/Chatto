/*
 The MIT License (MIT)

 Copyright (c) 2015-present Badoo Trading Limited.

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
*/

import PhotosUI

protocol PhotosInputDataProviderDelegate: class {
    func handlePhotosInpudDataProviderUpdate(dataProvider: PhotosInputDataProviderProtocol, updateBlock: () -> Void)
}

protocol PhotosInputDataProviderProtocol {
    weak var delegate: PhotosInputDataProviderDelegate? { get set }
    var count: Int { get }
    func requestPreviewImageAtIndex(index: Int, targetSize: CGSize, completion: (UIImage) -> Void) -> Int32
    func requestFileURLAtIndex(index: Int, completion: (NSURL?) -> Void)
    func cancelPreviewImageRequest(requestID: Int32)
}

class PhotosInputPlaceholderDataProvider: PhotosInputDataProviderProtocol {
    weak var delegate: PhotosInputDataProviderDelegate?

    let numberOfPlaceholders: Int

    init(numberOfPlaceholders: Int = 5) {
        self.numberOfPlaceholders = numberOfPlaceholders
    }

    var count: Int {
        return self.numberOfPlaceholders
    }

    func requestPreviewImageAtIndex(index: Int, targetSize: CGSize, completion: (UIImage) -> Void) -> Int32 {
        return 0
    }

    func requestFileURLAtIndex(index: Int, completion: (NSURL?) -> Void) {
    }

    func cancelPreviewImageRequest(requestID: Int32) {
    }
}

@objc
class PhotosInputDataProvider: NSObject, PhotosInputDataProviderProtocol, PHPhotoLibraryChangeObserver {
    weak var delegate: PhotosInputDataProviderDelegate?
    private var imageManager = PHCachingImageManager()
    private var fetchResult: PHFetchResult!
    override init() {
        let options = PHFetchOptions()
        options.sortDescriptors = [ NSSortDescriptor(key: "modificationDate", ascending: false) ]
        self.fetchResult = PHAsset.fetchAssetsWithMediaType(.Image, options: options)
        super.init()
        PHPhotoLibrary.sharedPhotoLibrary().registerChangeObserver(self)
    }

    deinit {
        PHPhotoLibrary.sharedPhotoLibrary().unregisterChangeObserver(self)
    }

    var count: Int {
        return self.fetchResult.count
    }

    func requestPreviewImageAtIndex(index: Int, targetSize: CGSize, completion: (UIImage) -> Void) -> Int32 {
        assert(index >= 0 && index < self.fetchResult.count, "Index out of bounds")
        let asset = self.fetchResult[index] as! PHAsset
        let options = PHImageRequestOptions()
        options.deliveryMode = .HighQualityFormat
        options.networkAccessAllowed = true
        return self.imageManager.requestImageForAsset(asset, targetSize: targetSize, contentMode: .AspectFill, options: options) { (image, info) in
            if let image = image {
                completion(image)
            }
        }
    }

    func cancelPreviewImageRequest(requestID: Int32) {
        self.imageManager.cancelImageRequest(requestID)
    }

    func requestFileURLAtIndex(index: Int, completion: (NSURL?) -> Void) {
        assert(index >= 0 && index < self.fetchResult.count, "Index out of bounds")
        let asset = self.fetchResult[index] as! PHAsset
        let documentsPath = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .AllDomainsMask, true)[0]
        if asset.mediaType == .Video {
            let options = PHVideoRequestOptions()
            options.networkAccessAllowed = true
            let documentsPath = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .AllDomainsMask, true)[0]
            let outputURL = NSURL(fileURLWithPath: documentsPath).URLByAppendingPathComponent("mergeVideo\(arc4random()%1000)d").URLByAppendingPathExtension("mov")
            if NSFileManager.defaultManager().fileExistsAtPath(outputURL.absoluteString) {
                try! NSFileManager.defaultManager().removeItemAtPath(outputURL.absoluteString)
            }
            self.imageManager.requestExportSessionForVideo(asset, options: .None, exportPreset: AVAssetExportPresetMediumQuality) {(session, info) -> Void in
                if let session = session {
                    session.outputFileType = AVFileTypeQuickTimeMovie
                    session.outputURL = outputURL
                    session.exportAsynchronouslyWithCompletionHandler { () -> Void in
                        if session.status == .Completed {
                            completion(outputURL)
                        } else {
                            completion(nil)
                        }
                    }
                } else {
                    completion(nil)
                }
            }
        } else if asset.mediaType == .Image {
            let options = PHImageRequestOptions()
            options.networkAccessAllowed = true
            self.imageManager.requestImageForAsset(asset, targetSize: PHImageManagerMaximumSize, contentMode: .AspectFit, options: options) { (image, info) -> Void in
                if let degraded = info?[PHImageResultIsDegradedKey]?.boolValue where degraded {
                    return
                }
                if let image = image, data = UIImageJPEGRepresentation(image, 1.0) {
                    let outputURL = NSURL(fileURLWithPath: documentsPath).URLByAppendingPathComponent("image\(arc4random()%1000)d").URLByAppendingPathExtension("jpg")
                    if NSFileManager.defaultManager().fileExistsAtPath(outputURL.absoluteString) {
                        try! NSFileManager.defaultManager().removeItemAtPath(outputURL.absoluteString)
                    }
                    data.writeToURL(outputURL, atomically: true)
                    completion(outputURL)
                }
            }
        }
    }

    // MARK: PHPhotoLibraryChangeObserver

    func photoLibraryDidChange(changeInstance: PHChange) {
        // Photos may call this method on a background queue; switch to the main queue to update the UI.
        dispatch_async(dispatch_get_main_queue()) { [weak self]  in
            guard let sSelf = self else { return }

            if let changeDetails = changeInstance.changeDetailsForFetchResult(sSelf.fetchResult) {
                let updateBlock = { () -> Void in
                    self?.fetchResult = changeDetails.fetchResultAfterChanges
                }
                sSelf.delegate?.handlePhotosInpudDataProviderUpdate(sSelf, updateBlock: updateBlock)
            }
        }
    }
}

class PhotosInputWithPlaceholdersDataProvider: PhotosInputDataProviderProtocol, PhotosInputDataProviderDelegate {
    weak var delegate: PhotosInputDataProviderDelegate?
    private let photosDataProvider: PhotosInputDataProviderProtocol
    private let placeholdersDataProvider: PhotosInputDataProviderProtocol

    init(photosDataProvider: PhotosInputDataProviderProtocol, placeholdersDataProvider: PhotosInputDataProviderProtocol) {
        self.photosDataProvider = photosDataProvider
        self.placeholdersDataProvider = placeholdersDataProvider
        self.photosDataProvider.delegate = self
    }

    var count: Int {
        return max(self.photosDataProvider.count, self.placeholdersDataProvider.count)
    }

    func requestPreviewImageAtIndex(index: Int, targetSize: CGSize, completion: (UIImage) -> Void) -> Int32 {
        if index < self.photosDataProvider.count {
            return self.photosDataProvider.requestPreviewImageAtIndex(index, targetSize: targetSize, completion: completion)
        } else {
            return self.placeholdersDataProvider.requestPreviewImageAtIndex(index, targetSize: targetSize, completion: completion)
        }
    }

    func requestFileURLAtIndex(index: Int, completion: (NSURL?) -> Void) {
        if index < self.photosDataProvider.count {
            return self.photosDataProvider.requestFileURLAtIndex(index, completion: completion)
        } else {
            return self.placeholdersDataProvider.requestFileURLAtIndex(index, completion: completion)
        }
    }

    func cancelPreviewImageRequest(requestID: Int32) {
        return self.photosDataProvider.cancelPreviewImageRequest(requestID)
    }

    // MARK: PhotosInputDataProviderDelegate

    func handlePhotosInpudDataProviderUpdate(dataProvider: PhotosInputDataProviderProtocol, updateBlock: () -> Void) {
        self.delegate?.handlePhotosInpudDataProviderUpdate(self, updateBlock: updateBlock)
    }
}

