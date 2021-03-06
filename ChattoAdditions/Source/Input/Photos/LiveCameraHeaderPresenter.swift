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

import Foundation
import Photos

protocol LiveCameraHeaderPresenterProtocol {
    weak var delegate: LiveCameraHeaderPresenterDelegate? { get set }
}

protocol LiveCameraHeaderPresenterDelegate: class {
    func liveCameraHeaderPresenterImageSavedToPath(_ url: URL)
}

public final class LiveCameraHeaderPresenter:  LiveCameraHeaderDelegate, LiveCameraCaptureSessionDelegate {

    private typealias Class = LiveCameraHeaderPresenter
    public typealias AVAuthorizationStatusProvider = () -> AVAuthorizationStatus


    private let headerAppearance: LiveCameraHeaderAppearance
    private let authorizationStatusProvider: () -> AVAuthorizationStatus
    weak var delegate: LiveCameraHeaderPresenterDelegate?
    public init(headerAppearance: LiveCameraHeaderAppearance = LiveCameraHeaderAppearance.createDefaultAppearance(), authorizationStatusProvider: @escaping AVAuthorizationStatusProvider = LiveCameraHeaderPresenter.createDefaultCameraAuthorizationStatusProvider()) {
        self.headerAppearance = headerAppearance
        self.authorizationStatusProvider = authorizationStatusProvider
    }

    deinit {
        self.unsubscribeFromAppNotifications()
    }

    private static let reuseIdentifier = "LiveCameraheader"
    private static func createDefaultCameraAuthorizationStatusProvider() -> AVAuthorizationStatusProvider {
        return {
            return AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo)
        }
    }

    public static func registerCells(collectionView: UICollectionView) {
        collectionView.register(LiveCameraCell.self, forCellWithReuseIdentifier: Class.reuseIdentifier)
    }

    public func dequeueCell(collectionView: UICollectionView, indexPath: IndexPath) -> UICollectionViewCell {
        return collectionView.dequeueReusableCell(withReuseIdentifier: Class.reuseIdentifier, for: indexPath)
    }

    private weak var header: LiveCameraHeader?

    public func cellWillBeShown(_ header: UICollectionReusableView) {
        guard let header = header as? LiveCameraHeader else {
            assertionFailure("Invalid cell given to presenter")
            return
        }
        self.header = header
        self.header?.delegate = self
        self.configureCell()
        self.startCapturing()
    }

    public func cellWasHidden(_ cell: UICollectionReusableView) {
        guard let cell = cell as? LiveCameraHeader else {
            assertionFailure("Invalid cell given to presenter")
            return
        }

        if self.header === header {
            header?.captureLayer = nil
            self.header = nil
            self.stopCapturing()
        }
    }

    private func configureCell() {
        guard let cameraCell = self.header else { return }

        self.cameraAuthorizationStatus = self.authorizationStatusProvider()
        cameraCell.updateWithAuthorizationStatus(self.cameraAuthorizationStatus)
        cameraCell.appearance = self.headerAppearance

        if self.captureSession.isCapturing {
            cameraCell.captureLayer = self.captureSession.captureLayer
        } else {
            cameraCell.captureLayer = nil
        }

        cameraCell.onWasAddedToWindow = { [weak self] (cell) in
            guard let sSelf = self, sSelf.header === cell else { return }
            if !sSelf.cameraPickerIsVisible {
                sSelf.startCapturing()
            }
        }

        cameraCell.onWasRemovedFromWindow = { [weak self] (cell) in
            guard let sSelf = self, sSelf.header === cell else { return }
            if !sSelf.cameraPickerIsVisible {
                sSelf.stopCapturing()
            }
        }
    }

    // MARK: - App Notifications
    lazy var notificationCenter = NotificationCenter.default

    private func subscribeToAppNotifications() {
        self.notificationCenter.addObserver(self, selector: #selector(LiveCameraHeaderPresenter.handleWillResignActiveNotification), name: NSNotification.Name.UIApplicationWillResignActive, object: nil)
        self.notificationCenter.addObserver(self, selector: #selector(LiveCameraHeaderPresenter.handleDidBecomeActiveNotification), name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)
    }

    private func unsubscribeFromAppNotifications() {
        self.notificationCenter.removeObserver(self)
    }

    private var needsRestoreCaptureSession = false

    @objc
    private func handleWillResignActiveNotification() {
        if self.captureSession.isCapturing {
            self.needsRestoreCaptureSession = true
            self.stopCapturing()
        }
    }

    @objc
    private func handleDidBecomeActiveNotification() {
        if self.needsRestoreCaptureSession {
            self.needsRestoreCaptureSession = false
            self.startCapturing()
        }
    }

    var cameraPickerIsVisible = false
    func cameraPickerWillAppear() {
        self.cameraPickerIsVisible = true
        self.stopCapturing()
    }

    func cameraPickerDidDisappear() {
        self.cameraPickerIsVisible = false
        self.startCapturing()
    }

    func startCapturing() {
        guard self.isCaptureAvailable, let _ = self.header else { return }

        self.captureSession.delegate = self
        self.captureSession.startCapturing() { [weak self] in
            self?.header?.captureLayer = self?.captureSession.captureLayer
        }
    }

    func stopCapturing() {
        guard self.isCaptureAvailable else { return }

        self.captureSession.stopCapturing() { [weak self] in
            self?.header?.captureLayer = nil
        }
    }

    private var isCaptureAvailable: Bool {
        switch self.cameraAuthorizationStatus {
        case .notDetermined, .restricted, .denied:
            return false
        case .authorized:
            return true
        }
    }

    lazy var captureSession: LiveCameraCaptureSessionProtocol = LiveCameraCaptureSession()

    private var cameraAuthorizationStatus: AVAuthorizationStatus = .notDetermined {
        didSet {
            if self.isCaptureAvailable {
                self.subscribeToAppNotifications()
            } else {
                self.unsubscribeFromAppNotifications()
            }
        }
    }
    
    internal func liveCameraHeaderTakePhoto() {
        self.captureSession.takePhoto()
    }

    internal func liveCameraHeaderChangeCamera() {
        self.captureSession.changeCamera()
    }

    internal func liveCameraCaptureSessionPhotoToken(_ image: Data) {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .allDomainsMask, true)[0]
        let outputURL = URL(fileURLWithPath: documentsPath).appendingPathComponent("image\(arc4random()%1000)d").appendingPathExtension("jpg")
        if FileManager.default.fileExists(atPath: outputURL.absoluteString) {
            try! FileManager.default.removeItem(atPath: outputURL.absoluteString)
        }
        if (try? image.write(to: outputURL, options: .atomic)) != nil {
            self.delegate?.liveCameraHeaderPresenterImageSavedToPath(outputURL)
//            completion(outputURL)
        } else {
//            completion(nil)
        }
    }
}
