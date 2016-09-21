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

import UIKit

open class PhotoMessageCollectionViewCellDefaultStyle: PhotoMessageCollectionViewCellStyleProtocol {
    typealias Class = PhotoMessageCollectionViewCellDefaultStyle

    public struct BubbleMasks {
        public let incomingTail: () -> UIImage
        public let incomingNoTail: () -> UIImage
        public let outgoingTail: () -> UIImage
        public let outgoingNoTail: () -> UIImage
        public let tailWidth: CGFloat
        public init(
            incomingTail: @autoclosure @escaping () -> UIImage,
            incomingNoTail: @autoclosure @escaping () -> UIImage,
            outgoingTail: @autoclosure @escaping () -> UIImage,
            outgoingNoTail: @autoclosure @escaping () -> UIImage,
            tailWidth: CGFloat) {
                self.incomingTail = incomingTail
                self.incomingNoTail = incomingNoTail
                self.outgoingTail = outgoingTail
                self.outgoingNoTail = outgoingNoTail
                self.tailWidth = tailWidth
        }
    }

    public struct Sizes {
        public let aspectRatioIntervalForSquaredSize: ClosedRange<CGFloat>
        public let photoSizeLandscape: CGSize
        public let photoSizePortrait: CGSize
        public let photoSizeSquare: CGSize
        public init(
            aspectRatioIntervalForSquaredSize: ClosedRange<CGFloat>,
            photoSizeLandscape: CGSize,
            photoSizePortrait: CGSize,
            photoSizeSquare: CGSize) {
                self.aspectRatioIntervalForSquaredSize = aspectRatioIntervalForSquaredSize
                self.photoSizeLandscape = photoSizeLandscape
                self.photoSizePortrait = photoSizePortrait
                self.photoSizeSquare = photoSizeSquare
        }
    }

    lazy private var maskImageIncomingTail: UIImage = {
        return UIImage(named: "bubble-incoming-tail", inBundle: NSBundle(forClass: self.dynamicType), compatibleWithTraitCollection: nil)!
    }()

    lazy private var maskImageIncomingNoTail: UIImage = {
        return UIImage(named: "bubble-incoming", inBundle: NSBundle(forClass: self.dynamicType), compatibleWithTraitCollection: nil)!
    }()

    lazy private var maskImageOutgoingTail: UIImage = {
        return UIImage(named: "bubble-outgoing-tail", inBundle: NSBundle(forClass: self.dynamicType), compatibleWithTraitCollection: nil)!
    }()

    lazy private var maskImageOutgoingNoTail: UIImage = {
        return UIImage(named: "bubble-outgoing", inBundle: NSBundle(forClass: self.dynamicType), compatibleWithTraitCollection: nil)!
    }()

    lazy private var placeholderBackgroundIncoming: UIImage = {
        return UIImage.bma_imageWithColor(self.baseStyle.baseColorIncoming, size: CGSize(width: 1, height: 1))
    }()

    lazy private var placeholderBackgroundOutgoing: UIImage = {
        return UIImage.bma_imageWithColor(self.baseStyle.baseColorOutgoing, size: CGSize(width: 1, height: 1))
    }()

    lazy private var placeholderIcon: UIImage = {
        return UIImage(named: "photo-bubble-placeholder-icon", in: Bundle(for: Class.self), compatibleWith: nil)!
    }()

    open func maskingImage(viewModel: PhotoMessageViewModelProtocol) -> UIImage {
        switch (viewModel.isIncoming, viewModel.showsTail) {
        case (true, true):
            return self.maskImageIncomingTail
        case (true, false):
            return self.maskImageIncomingNoTail
        case (false, true):
            return self.maskImageOutgoingTail
        case (false, false):
            return self.maskImageOutgoingNoTail
        }
    }

    open func borderImage(viewModel: PhotoMessageViewModelProtocol) -> UIImage? {
        return self.baseStyle.borderImage(viewModel: viewModel)
    }

    open func placeholderBackgroundImage(viewModel: PhotoMessageViewModelProtocol) -> UIImage {
        return viewModel.isIncoming ? self.placeholderBackgroundIncoming : self.placeholderBackgroundOutgoing
    }

    open func placeholderIconImage(viewModel: PhotoMessageViewModelProtocol) -> (icon: UIImage?, tintColor: UIColor?) {
        if viewModel.image.value == nil && viewModel.transferStatus.value == .failed {
            let tintColor = viewModel.isIncoming ? self.colors.placeholderIconTintIncoming : self.colors.placeholderIconTintOutgoing
            return (self.placeholderIcon, tintColor)
        }
        return (nil, nil)
    }

    open func tailWidth(viewModel: PhotoMessageViewModelProtocol) -> CGFloat {
        return self.bubbleMasks.tailWidth
    }

    open func bubbleSize(viewModel: PhotoMessageViewModelProtocol) -> CGSize {
        let aspectRatio = viewModel.imageSize.height > 0 ? viewModel.imageSize.width / viewModel.imageSize.height : 0

        if aspectRatio == 0 || self.sizes.aspectRatioIntervalForSquaredSize.contains(aspectRatio) {
            return self.sizes.photoSizeSquare
        } else if aspectRatio < self.sizes.aspectRatioIntervalForSquaredSize.lowerBound {
            return self.sizes.photoSizePortrait
        } else {
            return self.styleConstants.photoSizeLandscape
        }
    }

    open func progressIndicatorColor(viewModel: PhotoMessageViewModelProtocol) -> UIColor {
        return viewModel.isIncoming ? self.colors.progressIndicatorColorIncoming : self.colors.progressIndicatorColorOutgoing
    }

    open func overlayColor(viewModel: PhotoMessageViewModelProtocol) -> UIColor? {
        let showsOverlay = viewModel.image.value != nil && (viewModel.transferStatus.value == .transfering || viewModel.status != MessageViewModelStatus.success)
        return showsOverlay ? self.colors.overlayColor : nil
    }

}

public extension PhotoMessageCollectionViewCellDefaultStyle { // Default values

    static public func createDefaultBubbleMasks() -> BubbleMasks {
        return BubbleMasks(
            incomingTail: UIImage(named: "bubble-incoming-tail", in: Bundle(for: Class.self), compatibleWith: nil)!,
            incomingNoTail: UIImage(named: "bubble-incoming", in: Bundle(for: Class.self), compatibleWith: nil)!,
            outgoingTail: UIImage(named: "bubble-outgoing-tail", in: Bundle(for: Class.self), compatibleWith: nil)!,
            outgoingNoTail: UIImage(named: "bubble-outgoing", in: Bundle(for: Class.self), compatibleWith: nil)!,
            tailWidth: 6
        )
    }

    static public func createDefaultSizes() -> Sizes {
        return Sizes(
            aspectRatioIntervalForSquaredSize: 0.90...1.10,
            photoSizeLandscape: CGSize(width: 210, height: 136),
            photoSizePortrait: CGSize(width: 136, height: 210),
            photoSizeSquare: CGSize(width: 210, height: 210)
        )
    }

    static public func createDefaultColors() -> Colors {
        return Colors(
            placeholderIconTintIncoming: UIColor.bma_color(rgb: 0xced6dc),
            placeholderIconTintOutgoing: UIColor.bma_color(rgb: 0x508dfc),
            progressIndicatorColorIncoming: UIColor.bma_color(rgb: 0x98a3ab),
            progressIndicatorColorOutgoing: UIColor.white,
            overlayColor: UIColor.black.withAlphaComponent(0.70)
        )
    }
}
