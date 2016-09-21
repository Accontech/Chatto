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

open class KeyboardTracker {

    fileprivate enum KeyboardStatus {
        case hidden
        case showing
        case shown
    }

    fileprivate var keyboardStatus: KeyboardStatus = .hidden
    fileprivate let view: UIView
    fileprivate let inputContainerBottomConstraint: NSLayoutConstraint
    var trackingView: UIView {
        return self.keyboardTrackerView
    }
    fileprivate lazy var keyboardTrackerView: KeyboardTrackingView = {
        let trackingView = KeyboardTrackingView()
        trackingView.positionChangedCallback = { [weak self] in
            self?.layoutInputAtTrackingViewIfNeeded()
        }
        return trackingView
    }()

    var isTracking = false
    open var inputContainer: UIView
    fileprivate var notificationCenter: NotificationCenter

    init(viewController: UIViewController, inputContainer: UIView, inputContainerBottomContraint: NSLayoutConstraint, notificationCenter: NotificationCenter) {
        self.view = viewController.view
        self.inputContainer = inputContainer
        self.inputContainerBottomConstraint = inputContainerBottomContraint
        self.notificationCenter = notificationCenter
        self.notificationCenter.addObserver(self, selector: #selector(KeyboardTracker.keyboardWillShow(_:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        self.notificationCenter.addObserver(self, selector: #selector(KeyboardTracker.keyboardDidShow(_:)), name: NSNotification.Name.UIKeyboardDidShow, object: nil)
        self.notificationCenter.addObserver(self, selector: #selector(KeyboardTracker.keyboardWillHide(_:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        self.notificationCenter.addObserver(self, selector: #selector(KeyboardTracker.keyboardWillChangeFrame(_:)), name: NSNotification.Name.UIKeyboardWillChangeFrame, object: nil)
    }

    deinit {
        self.notificationCenter.removeObserver(self)
    }

    func startTracking() {
        self.isTracking = true
    }

    func stopTracking() {
        self.isTracking = false
    }

    @objc
    fileprivate func keyboardWillShow(_ notification: Notification) {
        guard self.isTracking else { return }
        let bottomConstraint = self.bottomConstraintFromNotification(notification)
        guard bottomConstraint > 0 else { return } // Some keyboards may report initial willShow/DidShow notifications with invalid positions
        self.keyboardStatus = .showing
        self.inputContainerBottomConstraint.constant = bottomConstraint
        self.view.layoutIfNeeded()
        self.adjustTrackingViewSizeIfNeeded()
    }

    @objc
    fileprivate func keyboardDidShow(_ notification: Notification) {
        guard self.isTracking else { return }
        let bottomConstraint = self.bottomConstraintFromNotification(notification)
        guard bottomConstraint > 0 else { return } // Some keyboards may report initial willShow/DidShow notifications with invalid positions
        self.keyboardStatus = .shown
        self.inputContainerBottomConstraint.constant = bottomConstraint
        self.view.layoutIfNeeded()
        self.layoutTrackingViewIfNeeded()
    }

    @objc
    fileprivate func keyboardWillChangeFrame(_ notification: Notification) {
        guard self.isTracking else { return }
        let bottomConstraint = self.bottomConstraintFromNotification(notification)
        if bottomConstraint == 0 {
            self.keyboardStatus = .hidden
            self.layoutInputAtBottom()
        }
    }

    @objc
    fileprivate func keyboardWillHide(_ notification: Notification) {
        guard self.isTracking else { return }
        self.keyboardStatus = .hidden
        self.layoutInputAtBottom()
    }

    fileprivate func bottomConstraintFromNotification(_ notification: Notification) -> CGFloat {
        guard let rect = ((notification as NSNotification).userInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue else { return 0 }
        guard rect.height > 0 else { return 0 }
        let rectInView = self.view.convert(rect, from: nil)
        guard rectInView.maxY >= self.view.bounds.height else { return 0 } // Undocked keyboard
        return max(0, self.view.bounds.height - rectInView.minY - self.trackingView.bounds.height)
    }

    fileprivate func bottomConstraintFromTrackingView() -> CGFloat {
        let trackingViewRect = self.view.convert(self.keyboardTrackerView.bounds, from: self.keyboardTrackerView)
        return  self.view.bounds.height - trackingViewRect.maxY
    }

    func layoutTrackingViewIfNeeded() {
        guard self.isTracking && self.keyboardStatus == .shown else { return }
        self.adjustTrackingViewSizeIfNeeded()
    }

    fileprivate func adjustTrackingViewSizeIfNeeded() {
        let inputContainerHeight = self.inputContainer.bounds.height
        let trackerViewHeight = self.trackingView.bounds.height
        if trackerViewHeight != inputContainerHeight {
            self.keyboardTrackerView.bounds = CGRect(origin: CGPoint.zero, size: CGSize(width: self.keyboardTrackerView.bounds.width, height: inputContainerHeight))
        }
    }

    fileprivate func layoutInputAtBottom() {
        self.keyboardTrackerView.bounds = CGRect(origin: CGPoint.zero, size: CGSize(width: self.keyboardTrackerView.bounds.width, height: 0))
        self.inputContainerBottomConstraint.constant = 0
        self.view.layoutIfNeeded()
    }

    func layoutInputAtTrackingViewIfNeeded() {
        guard self.isTracking && self.keyboardStatus == .shown else { return }
        let newBottomConstraint = self.bottomConstraintFromTrackingView()
        self.inputContainerBottomConstraint.constant = newBottomConstraint
        self.view.layoutIfNeeded()
    }
}

private class KeyboardTrackingView: UIView {

    var positionChangedCallback: (() -> Void)?
    var observedView: UIView?

    deinit {
        if let observedView = self.observedView {
            observedView.removeObserver(self, forKeyPath: "center")
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.commonInit()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.commonInit()
    }

    fileprivate func commonInit() {
        self.autoresizingMask = .flexibleHeight
        self.isUserInteractionEnabled = false
        self.backgroundColor = UIColor.clear
        self.isHidden = true
    }

    override var bounds: CGRect {
        didSet {
            if oldValue.size != self.bounds.size {
                self.invalidateIntrinsicContentSize()
            }
        }
    }

    fileprivate override var intrinsicContentSize : CGSize {
        return self.bounds.size
    }

    override func willMove(toSuperview newSuperview: UIView?) {
        if let observedView = self.observedView {
            observedView.removeObserver(self, forKeyPath: "center")
            self.observedView = nil
        }

        if let newSuperview = newSuperview {
            newSuperview.addObserver(self, forKeyPath: "center", options: [.new, .old], context: nil)
            self.observedView = newSuperview
        }

        super.willMove(toSuperview: newSuperview)
    }

    fileprivate override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard let object = object, let superview = self.superview else { return }
        if object === superview {
            guard let sChange = change else { return }
            let oldCenter = (sChange[NSKeyValueChangeKey.oldKey] as! NSValue).cgPointValue
            let newCenter = (sChange[NSKeyValueChangeKey.newKey] as! NSValue).cgPointValue
            if oldCenter != newCenter {
                self.positionChangedCallback?()
            }
        }
    }
}
