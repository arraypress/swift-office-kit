//
//  ParagraphText.swift
//  OfficeKit
//
//  Created by David Sherlock on 2026.
//
//  The trap every Word templating tool falls into: a paragraph's text is cut
//  into runs wherever formatting, spell-checking or revision history
//  changed, and a placeholder can be cut with it. MEASURED on 88 real
//  templates from the docxtemplater test corpus: Word had split 65 of 197
//  tags (33%) across runs, LibreOffice 11 of 90 (12%), WPS 1 of 18 — a
//  find-and-replace inside each run would have missed a third of Word's.
//
//  So the paragraph is read as one string across all its `w:t` nodes, the
//  placeholder is found in that, and the replacement goes into the run the
//  placeholder STARTS in — keeping that run's formatting — while the pieces
//  of it in later runs are cut away.
//

import Foundation

/// The text of one paragraph, across its runs, and how to replace in it.
struct ParagraphText {

    /// The `w:t` nodes, in order.
    let nodes: [XMLElement]
    /// Where each node's text starts in ``text``, in UTF-16 offsets.
    private(set) var starts: [Int]
    /// The paragraph's text, all runs joined.
    private(set) var text: String

    /// The text of a `w:p`, not counting paragraphs nested inside it.
    init(paragraph: XMLElement) {
        nodes = paragraph.descendants(named: "w:t", stoppingAt: "w:p")
        var starts: [Int] = [], text = ""
        for node in nodes {
            starts.append((text as NSString).length)
            text += node.stringValue ?? ""
        }
        self.starts = starts
        self.text = text
    }

    /// The node holding a UTF-16 offset.
    private func node(at offset: Int) -> Int {
        var index = 0
        for (candidate, start) in starts.enumerated() where start <= offset {
            let length = ((nodes[candidate].stringValue ?? "") as NSString).length
            if offset < start + length { return candidate }
            index = candidate
        }
        return index
    }

    /// Whether a range lies across more than one node.
    func isSplit(_ range: NSRange) -> Bool {
        guard range.length > 0 else { return false }
        return node(at: range.location) != node(at: range.location + range.length - 1)
    }

    /// Replaces a range of the paragraph's text.
    ///
    /// The value goes into the node the range starts in; later nodes lose
    /// their share of the range. A newline in the value becomes a `w:br`
    /// followed by a new `w:t` in the same run, so the line keeps the run's
    /// formatting.
    ///
    /// Callers replace from the LAST match to the first, so earlier offsets
    /// stay true.
    mutating func replace(_ range: NSRange, with value: String) {
        guard !nodes.isEmpty else { return }
        let first = node(at: range.location)
        let last = node(at: max(range.location, range.location + range.length - 1))
        let firstText = (nodes[first].stringValue ?? "") as NSString
        let lastText = (nodes[last].stringValue ?? "") as NSString
        let prefix = firstText.substring(to: range.location - starts[first])
        let suffixStart = range.location + range.length - starts[last]
        let suffix = lastText.substring(from: min(suffixStart, lastText.length))

        var lines = (prefix + value + (first == last ? suffix : "")).components(separatedBy: "\n")
        set(nodes[first], lines.removeFirst())
        if first != last {
            for middle in (first + 1)..<last { set(nodes[middle], "") }
            set(nodes[last], suffix)
        }
        // Further lines: a break, then the text, inside the same run.
        if !lines.isEmpty, let run = nodes[first].parent as? XMLElement {
            var position = nodes[first].index + 1
            for line in lines {
                run.insertChild(XMLElement.named("w:br"), at: position)
                let node = XMLElement.named("w:t")
                set(node, line)
                run.insertChild(node, at: position + 1)
                position += 2
            }
        }
        self = ParagraphText(paragraph: paragraphElement ?? XMLElement(name: "w:p"))
    }

    /// The paragraph these nodes belong to.
    private var paragraphElement: XMLElement? {
        var node: XMLNode? = nodes.first?.parent
        while let current = node {
            if let element = current as? XMLElement, element.name == "w:p" { return element }
            node = current.parent
        }
        return nil
    }

    /// Sets a text node, keeping leading and trailing spaces.
    private func set(_ node: XMLElement, _ text: String) {
        node.stringValue = text
        if text.first == " " || text.last == " " || text.contains("  ") {
            node.set("xml:space", "preserve")
        }
    }
}
