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

open class EmojisChatInputItem: ChatInputItemProtocol {
    typealias Class = EmojisChatInputItem

    public var textInputHandler: ((String) -> Void)?
    public var imageInputHandler: ((Data) -> Void)?
    
    public var emojiSelectionHandler: ((String) -> Void)?
    public var backspaceHandler: (() -> Void)?
    
    public var cameraPermissionHandler: (() -> Void)?

    public weak var presentingController: UIViewController?

    let buttonAppearance: TabInputButtonAppearance
    let inputViewAppearance: EmojisInputViewAppearance
    public init(presentingController: UIViewController?,
                tabInputButtonAppearance: TabInputButtonAppearance = Class.createDefaultButtonAppearance(),
                inputViewAppearance: EmojisInputViewAppearance = Class.createDefaultInputViewAppearance()) {
        self.presentingController = presentingController
        self.buttonAppearance = tabInputButtonAppearance
        self.inputViewAppearance = inputViewAppearance
    }

    public static func createDefaultButtonAppearance() -> TabInputButtonAppearance {
        let images: [UIControlStateWrapper: UIImage] = [
            UIControlStateWrapper(state: .normal): UIImage(named: "emoji-icon-unselected", in: Bundle(for: Class.self), compatibleWith: nil)!,
            UIControlStateWrapper(state: .selected): UIImage(named: "emoji-icon-selected", in: Bundle(for: Class.self), compatibleWith: nil)!,
            UIControlStateWrapper(state: .highlighted): UIImage(named: "emoji-icon-selected", in: Bundle(for: Class.self), compatibleWith: nil)!
        ]
        return TabInputButtonAppearance(images: images, size: nil)
    }

    public static func createDefaultInputViewAppearance() -> EmojisInputViewAppearance {
        return EmojisInputViewAppearance(liveCameraCellAppearence: LiveCameraCellAppearance.createDefaultAppearance())
    }

    lazy private var internalTabView: UIButton = {
        let button: UIButton = TabInputButton.makeInputButton(withAppearance: self.buttonAppearance, accessibilityID: "emojis.chat.input.view")
        //button.isEnabled = false
        return button
    }()

    lazy var emojisInputView: EmojisInputViewProtocol = {
        let emojisInputView = EmojisInputView(presentingController: self.presentingController, appearance: self.inputViewAppearance)
        emojisInputView.delegate = self
        return emojisInputView
    }()

    open var selected = false {
        didSet {
            self.internalTabView.isSelected = self.selected
        }
    }

    // MARK: - ChatInputItemProtocol

    open var presentationMode: ChatInputItemPresentationMode {
        return .customView
    }

    open var showsSendButton: Bool {
        return true
    }

    open var inputView: UIView? {
        return self.emojisInputView as? UIView
    }

    open var tabView: UIView {
        return self.internalTabView
    }

    
    public func handleInput(_ input: AnyObject) {
        print(#function)

        if let text = input as? String {
            self.textInputHandler?(text)
        }
    }
    
    public func handleImageInput(_ input: AnyObject) {
        print(#function)

        if let image = input as? Data {
            self.imageInputHandler?(image)
        }
    }
}

// MARK: - EmojisInputViewDelegate
extension EmojisChatInputItem: EmojisInputViewDelegate {
    func inputView(_ inputView: EmojisInputViewProtocol, didSelectEmoji emoji: String?) {
        print(#function)
        
        if let emoji = emoji {
            self.emojiSelectionHandler?(emoji)
        }
    }
    
    func inputView(_ inputView: EmojisInputViewProtocol, didPressBackspace: Bool) {
        print(#function)
        
        self.backspaceHandler?()
    }
}
