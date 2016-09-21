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

public protocol ChatItemsDecoratorProtocol {
    func decorateItems(_ chatItems: [ChatItemProtocol]) -> [DecoratedChatItem]
}

public struct DecoratedChatItem {
    public let chatItem: ChatItemProtocol
    public let decorationAttributes: ChatItemDecorationAttributesProtocol?
    public init(chatItem: ChatItemProtocol, decorationAttributes: ChatItemDecorationAttributesProtocol?) {
        self.chatItem = chatItem
        self.decorationAttributes = decorationAttributes
    }
}

open class ChatViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {

    public struct Constants {
        var updatesAnimationDuration: TimeInterval = 0.33
        var defaultContentInsets = UIEdgeInsets(top: 10, left: 0, bottom: 10, right: 0)
        var defaultScrollIndicatorInsets = UIEdgeInsets.zero
        var preferredMaxMessageCount: Int? = 500 // It not nil, will ask data source to reduce number of messages when limit is reached. @see ChatDataSourceDelegateProtocol
        var preferredMaxMessageCountAdjustment: Int = 400 // When the above happens, will ask to adjust with this value. It may be wise for this to be smaller to reduce number of adjustments
        var autoloadingFractionalThreshold: CGFloat = 0.05 // in [0, 1]
    }

    open var constants = Constants()

    open fileprivate(set) var collectionView: UICollectionView!
    var decoratedChatItems = [DecoratedChatItem]()
    open var chatDataSource: ChatDataSourceProtocol? {
        didSet {
            self.chatDataSource?.delegate = self
            self.enqueueModelUpdate(context: .reload)
        }
    }

    deinit {
        self.collectionView.delegate = nil
        self.collectionView.dataSource = nil
    }

    open override func loadView() {
        self.view = BaseChatViewControllerView() // http://stackoverflow.com/questions/24596031/uiviewcontroller-with-inputaccessoryview-is-not-deallocated
        self.view.backgroundColor = UIColor.white
    }
    override open func viewDidLoad() {
        super.viewDidLoad()
        self.addCollectionView()
        self.addInputViews()
    }

    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.keyboardTracker.startTracking()
    }

    open override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.keyboardTracker.stopTracking()
    }

    fileprivate func addCollectionView() {
        self.collectionView = UICollectionView(frame: CGRect.zero, collectionViewLayout: self.createCollectionViewLayout)
        self.collectionView.contentInset = self.constants.defaultContentInsets
        self.collectionView.scrollIndicatorInsets = self.constants.defaultScrollIndicatorInsets
        self.collectionView.alwaysBounceVertical = true
        self.collectionView.backgroundColor = UIColor.clear
        self.collectionView.keyboardDismissMode = .interactive
        self.collectionView.showsVerticalScrollIndicator = true
        self.collectionView.showsHorizontalScrollIndicator = false
        self.collectionView.allowsSelection = false
        self.collectionView.translatesAutoresizingMaskIntoConstraints = false
        self.collectionView.autoresizingMask = UIViewAutoresizing()
        self.view.addSubview(self.collectionView)
        self.view.addConstraint(NSLayoutConstraint(item: self.view, attribute: .top, relatedBy: .equal, toItem: self.collectionView, attribute: .top, multiplier: 1, constant: 0))
        self.view.addConstraint(NSLayoutConstraint(item: self.view, attribute: .leading, relatedBy: .equal, toItem: self.collectionView, attribute: .leading, multiplier: 1, constant: 0))
        self.view.addConstraint(NSLayoutConstraint(item: self.view, attribute: .bottom, relatedBy: .equal, toItem: self.collectionView, attribute: .bottom, multiplier: 1, constant: 0))
        self.view.addConstraint(NSLayoutConstraint(item: self.view, attribute: .trailing, relatedBy: .equal, toItem: self.collectionView, attribute: .trailing, multiplier: 1, constant: 0))
        self.collectionView.dataSource = self
        self.collectionView.delegate = self
        self.accessoryViewRevealer = AccessoryViewRevealer(collectionView: self.collectionView)

        self.presenterBuildersByType = self.createPresenterBuilders()

        for presenterBuilder in self.presenterBuildersByType.flatMap({ $0.1 }) {
            presenterBuilder.presenterType.registerCells(self.collectionView)
        }
        DummyChatItemPresenter.registerCells(self.collectionView)
    }

    fileprivate var inputContainerBottomConstraint: NSLayoutConstraint!
    fileprivate func addInputViews() {
        self.inputContainer = UIView(frame: CGRect.zero)
        self.inputContainer.autoresizingMask = UIViewAutoresizing()
        self.inputContainer.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(self.inputContainer)
        self.view.addConstraint(NSLayoutConstraint(item: self.inputContainer, attribute: .top, relatedBy: .greaterThanOrEqual, toItem: self.topLayoutGuide, attribute: .bottom, multiplier: 1, constant: 0))
        self.view.addConstraint(NSLayoutConstraint(item: self.view, attribute: .leading, relatedBy: .equal, toItem: self.inputContainer, attribute: .leading, multiplier: 1, constant: 0))
        self.view.addConstraint(NSLayoutConstraint(item: self.view, attribute: .trailing, relatedBy: .equal, toItem: self.inputContainer, attribute: .trailing, multiplier: 1, constant: 0))
        self.inputContainerBottomConstraint = NSLayoutConstraint(item: self.view, attribute: .bottom, relatedBy: .equal, toItem: self.inputContainer, attribute: .bottom, multiplier: 1, constant: 0)
        self.view.addConstraint(self.inputContainerBottomConstraint)

        let inputView = self.createChatInputView()
        self.inputContainer.addSubview(inputView)
        self.inputContainer.addConstraint(NSLayoutConstraint(item: self.inputContainer, attribute: .top, relatedBy: .equal, toItem: inputView, attribute: .top, multiplier: 1, constant: 0))
        self.inputContainer.addConstraint(NSLayoutConstraint(item: self.inputContainer, attribute: .leading, relatedBy: .equal, toItem: inputView, attribute: .leading, multiplier: 1, constant: 0))
        self.inputContainer.addConstraint(NSLayoutConstraint(item: self.inputContainer, attribute: .bottom, relatedBy: .equal, toItem: inputView, attribute: .bottom, multiplier: 1, constant: 0))
        self.inputContainer.addConstraint(NSLayoutConstraint(item: self.inputContainer, attribute: .trailing, relatedBy: .equal, toItem: inputView, attribute: .trailing, multiplier: 1, constant: 0))

        self.keyboardTracker = KeyboardTracker(viewController: self, inputContainer: self.inputContainer, inputContainerBottomContraint: self.inputContainerBottomConstraint, notificationCenter: self.notificationCenter)
        (self.view as? BaseChatViewControllerView)?.bmaInputAccessoryView = self.keyboardTracker.trackingView
    }
    var notificationCenter = NotificationCenter.default
    open var keyboardTracker: KeyboardTracker!

    open var isFirstLayout: Bool = true
    override open func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        self.adjustCollectionViewInsets()
        self.keyboardTracker.layoutTrackingViewIfNeeded()

        if self.isFirstLayout {
            self.updateQueue.start()
            self.isFirstLayout = false
        }
    }

    fileprivate func adjustCollectionViewInsets() {
        let isInteracting = self.collectionView.panGestureRecognizer.numberOfTouches > 0
        let isBouncingAtTop = isInteracting && self.collectionView.contentOffset.y < -self.collectionView.contentInset.top
        if isBouncingAtTop { return }

        let inputHeightWithKeyboard = self.view.bounds.height - self.inputContainer.frame.minY
        let newInsetBottom = self.constants.defaultContentInsets.bottom + inputHeightWithKeyboard
        let insetBottomDiff = newInsetBottom - self.collectionView.contentInset.bottom

        let contentSize = self.collectionView.collectionViewLayout.collectionViewContentSize
        let allContentFits = self.collectionView.bounds.height - newInsetBottom - (contentSize.height + self.collectionView.contentInset.top) >= 0

        let currentDistanceToBottomInset = max(0, self.collectionView.bounds.height - self.collectionView.contentInset.bottom - (contentSize.height - self.collectionView.contentOffset.y))
        let newContentOffsetY = self.collectionView.contentOffset.y + insetBottomDiff - currentDistanceToBottomInset

        self.collectionView.contentInset.bottom = newInsetBottom
        self.collectionView.scrollIndicatorInsets.bottom = self.constants.defaultScrollIndicatorInsets.bottom + inputHeightWithKeyboard
        let inputIsAtBottom = self.view.bounds.maxY - self.inputContainer.frame.maxY <= 0

        if allContentFits {
            self.collectionView.contentOffset.y = -self.collectionView.contentInset.top
        } else if !isInteracting || inputIsAtBottom {
            self.collectionView.contentOffset.y = newContentOffsetY
        }

        self.workaroundContentInsetBugiOS_9_0_x()
    }

    func workaroundContentInsetBugiOS_9_0_x() {
        // Fix for http://www.openradar.me/22106545
        self.collectionView.contentInset.top = self.topLayoutGuide.length + self.constants.defaultContentInsets.top
        self.collectionView.scrollIndicatorInsets.top = self.topLayoutGuide.length + self.constants.defaultScrollIndicatorInsets.top
    }

    func rectAtIndexPath(_ indexPath: IndexPath?) -> CGRect? {
        if let indexPath = indexPath {
            return self.collectionView.collectionViewLayout.layoutAttributesForItem(at: indexPath)?.frame
        }
        return nil
    }

    var autoLoadingEnabled: Bool = false
    var accessoryViewRevealer: AccessoryViewRevealer!
    var inputContainer: UIView!
    var presenterBuildersByType = [ChatItemType: [ChatItemPresenterBuilderProtocol]]()
    var presenters = [ChatItemPresenterProtocol]()
    let presentersByChatItem = NSMapTable<???ChatItemProtocol???, AnyObject>(keyOptions: .weakMemory, valueOptions: NSPointerFunctions.Options())
    let presentersByCell = NSMapTable<UICollectionViewCell, AnyObject>(keyOptions: .weakMemory, valueOptions: .weakMemory)
    var updateQueue: SerialTaskQueueProtocol = SerialTaskQueue()

    open func createPresenterBuilders() -> [ChatItemType: [ChatItemPresenterBuilderProtocol]] {
        assert(false, "Override in subclass")
        return [ChatItemType: [ChatItemPresenterBuilderProtocol]]()
    }

    open func createChatInputView() -> UIView {
        assert(false, "Override in subclass")
        return UIView()
    }

    /**
     - You can use a decorator to:
        - Provide the ChatCollectionViewLayout with margins between messages
        - Provide to your pressenters additional attributes to help them configure their cells (for instance if a bubble should show a tail)
        - You can also add new items (for instance time markers or failed cells)
    */
    open var chatItemsDecorator: ChatItemsDecoratorProtocol?

    open var createCollectionViewLayout: UICollectionViewLayout {
        let layout = ChatCollectionViewLayout()
        layout.delegate = self
        return layout
    }

    var layoutModel = ChatCollectionViewLayoutModel.createModel(0, itemsLayoutData: [])
}

extension ChatViewController { // Rotation

    open override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        let shouldScrollToBottom = self.isScrolledAtBottom()
        let referenceIndexPath = self.collectionView.indexPathsForVisibleItems.first
        let oldRect = self.rectAtIndexPath(referenceIndexPath)
        coordinator.animate(alongsideTransition: { (context) -> Void in
            if shouldScrollToBottom {
                self.scrollToBottom(animated: false)
            } else {
                let newRect = self.rectAtIndexPath(referenceIndexPath)
                self.scrollToPreservePosition(oldRefRect: oldRect, newRefRect: newRect)
            }
        }, completion: nil)
    }
}
