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
import Chatto


protocol EmojisInputViewProtocol {
    weak var delegate: EmojisInputViewDelegate? { get set }
    weak var presentingController: UIViewController? { get }
}

protocol EmojisInputViewDelegate: class {
    func inputView(_ inputView: EmojisInputViewProtocol, didSelectEmoji emoji: String?)
    func inputView(_ inputView: EmojisInputViewProtocol, didPressBackspace: Bool)
}

public struct EmojisInputViewAppearance { // (Appearance for collectionView style implementation)
    public var liveCameraCellAppearence: LiveCameraCellAppearance
    public init(liveCameraCellAppearence: LiveCameraCellAppearance) {
        self.liveCameraCellAppearence = liveCameraCellAppearence
    }
}

class EmojisInputView: UIView, EmojisInputViewProtocol {

    weak var delegate: EmojisInputViewDelegate?
    override init(frame: CGRect) {
        super.init(frame: frame)
        addEmojiKeyboardView()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        addEmojiKeyboardView()
    }

    weak var presentingController: UIViewController?
    var appearance: EmojisInputViewAppearance?
    init(presentingController: UIViewController?, appearance: EmojisInputViewAppearance) {
        super.init(frame: CGRect.zero)
        self.presentingController = presentingController
        self.appearance = appearance
        addEmojiKeyboardView()
    }

    deinit {
    }
    
    private func addEmojiKeyboardView() {
        let keyboardRect = CGRect(x: 0, y: 0, width: self.frame.size.width, height: self.frame.size.height)
        let emojiKeyboardView = AGEmojiKeyboardView(frame: keyboardRect, dataSource: self)!
        
        emojiKeyboardView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        emojiKeyboardView.delegate = self
        self.addSubview(emojiKeyboardView)
    }
}


extension EmojisInputView: AGEmojiKeyboardViewDelegate {
    public func emojiKeyBoardView(_ emojiKeyBoardView: AGEmojiKeyboardView!, didUseEmoji emoji: String!) {
        self.delegate?.inputView(self, didSelectEmoji: emoji) // "💖"
    }
    
    public func emojiKeyBoardViewDidPressBackSpace(_ emojiKeyBoardView: AGEmojiKeyboardView!) {
        self.delegate?.inputView(self, didPressBackspace: true)
    }
}

extension EmojisInputView: AGEmojiKeyboardViewDataSource {
    public func emojiKeyboardView(_ emojiKeyboardView: AGEmojiKeyboardView!, imageForSelectedCategory category: AGEmojiKeyboardViewCategoryImage) -> UIImage! {
        return UIImage(named: "groupCallButton")!
    }
    
    public func emojiKeyboardView(_ emojiKeyboardView: AGEmojiKeyboardView!, imageForNonSelectedCategory category: AGEmojiKeyboardViewCategoryImage) -> UIImage! {
        return UIImage(named: "groupCallButton")!
    }
    
    public func backSpaceButtonImage(for emojiKeyboardView: AGEmojiKeyboardView!) -> UIImage! {
        return UIImage(named: "back_arrow")!
    }
}
