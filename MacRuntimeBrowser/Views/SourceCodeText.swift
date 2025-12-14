//
//  SourceCodeText.swift
//  RuntimeBrowser
//
//  Created by Phil Zakharchenko on 12/13/25.
//

import SwiftUI
import HighlightSwift

/// A SwiftUI view that renders syntax-highlighted source code.
struct SourceCodeText: NSViewRepresentable {
    /// The source code to display and highlight.
    let code: String
    
    /// The programming language for syntax highlighting.
    var language: HighlightLanguage?
    
    func makeNSView(context: Self.Context) -> NSScrollView {
        let scrollView = SourceCodeTextView.scrollableTextView()
        scrollView.automaticallyAdjustsContentInsets = true
        scrollView.hasVerticalScroller = true
        
        guard let textView = scrollView.documentView as? SourceCodeTextView else { return scrollView }

        textView.drawsBackground = false
        textView.isSelectable = true
        textView.isEditable = false
        textView.isRichText = false
        textView.usesFindBar = true
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainerInset = NSSize(width: 10, height: 10)
        textView.writingToolsBehavior = .none
        
        let font: NSFont = .monospacedSystemFont(ofSize: textView.font?.pointSize ?? NSFont.systemFontSize, weight: .regular)
        textView.font = font
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Self.Context) {
        guard let textView = scrollView.documentView as? SourceCodeTextView else { return }
        textView.code = code
        textView.language = language
    }
}

@MainActor
final class SourceCodeTextView: NSTextView {
    /// The source code to display and highlight.
    var code: String = "" {
        didSet {
            guard oldValue != code else { return }
            
            let unhighlightedString = NSMutableAttributedString(string: code.trimmingCharacters(in: .newlines))
            let fullRange = NSRange(location: 0, length: unhighlightedString.length)
            if let font {
                unhighlightedString.addAttributes([.font: font], range: fullRange)
            }
            
            textContentStorage?.textStorage?.setAttributedString(unhighlightedString)

            runHighlight()
        }
    }
    
    /// The programming language for syntax highlighting.
    var language: HighlightLanguage? {
        didSet {
            guard oldValue != language else { return }
            runHighlight()
        }
    }
    
    private nonisolated static let highlight = Highlight()
    private var highlightTask: Task<Void, Never>?
    
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        runHighlight()
    }
    
    /// Cancels any in-progress highlight task and starts a new one.
    func runHighlight() {
        highlightTask?.cancel()
        highlightTask = Task {
            await highlightText()
        }
    }
    
    /// Performs syntax highlighting asynchronously.
    func highlightText() async {
        let colors: CodeTextColors = .theme(.xcode)
        let schemeColors = effectiveAppearance.isDark ? colors.dark : colors.light
        
        let mode: HighlightMode
        if let language {
            mode = .language(language)
        } else {
            mode = .automatic
        }
        
        do {
            let highlightResult = try await Self.highlight.request(code, mode: mode, colors: schemeColors)
            guard !Task.isCancelled else { return }
            
            let attributedString = NSMutableAttributedString(attributedString: NSAttributedString(highlightResult.attributedText))

            let fullRange = NSRange(location: 0, length: attributedString.length)
            if let font {
                attributedString.addAttributes([.font: font], range: fullRange)
            }
            
            if highlightResult.isUndefined {
                attributedString.addAttributes([.foregroundColor: textColor ?? NSColor.textColor], range: fullRange)
            }
            
            textContentStorage?.textStorage?.setAttributedString(attributedString)
        } catch {
            NSAlert(error: error).runModal()
        }
    }
}

private extension NSAppearance {
    var isDark: Bool {
        bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
    }
}
