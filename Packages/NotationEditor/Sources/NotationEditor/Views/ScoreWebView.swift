// ScoreWebView.swift
// Renders Verovio SVG inside a WKWebView and bridges click events back to Swift.
//
// Entitlement note: com.apple.security.network.client is required by
// WKWebView's internal network sub-process even when no external requests
// are made by the application.
//
// Click bridge:
//   JS fires fetch('sn://select/<id>') on click.  A WKURLSchemeHandler registered
//   for the "sn" scheme intercepts the request without navigating the page.
//   This avoids WKScriptMessageHandler's Swift 6 actor-isolation problems and the
//   page-navigation side-effects of window.location.

import SwiftUI
import WebKit

// MARK: - Expanding WKWebView

public final class ExpandingWebView: WKWebView {
    override public var intrinsicContentSize: CGSize {
        CGSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
    }
}

// MARK: - View

public struct ScoreWebView: NSViewRepresentable {
    public let svg: String
    public let selectedID: String?
    public let onSelect: (String) -> Void

    public init(svg: String, selectedID: String?, onSelect: @escaping (String) -> Void) {
        self.svg = svg; self.selectedID = selectedID; self.onSelect = onSelect
    }

    public func makeNSView(context: Context) -> ExpandingWebView {
        let config = WKWebViewConfiguration()
        // Register the "sn" scheme so fetch('sn://select/...') reaches our handler.
        config.setURLSchemeHandler(context.coordinator, forURLScheme: "sn")

        let webView = ExpandingWebView(frame: .zero, configuration: config)
        webView.underPageBackgroundColor = .clear
        webView.navigationDelegate = context.coordinator
        return webView
    }

    public func updateNSView(_ webView: ExpandingWebView, context: Context) {
        if !svg.isEmpty, svg != context.coordinator.lastLoadedSVG {
            context.coordinator.lastLoadedSVG = svg
            webView.loadHTMLString(makeHTML(for: svg), baseURL: nil)
            context.coordinator.pendingSelectedID = selectedID
            return
        }

        let prev = context.coordinator.lastHighlightedID
        guard selectedID != prev else { return }
        context.coordinator.lastHighlightedID = selectedID
        applyHighlight(webView: webView, previousID: prev, newID: selectedID)
    }

    public func sizeThatFits(_ proposal: ProposedViewSize, nsView: ExpandingWebView, context: Context) -> CGSize? {
        CGSize(
            width:  proposal.width  ?? nsView.bounds.width,
            height: proposal.height ?? nsView.bounds.height
        )
    }

    public func makeCoordinator() -> Coordinator { Coordinator(onSelect: onSelect) }

    // MARK: - Coordinator

    public final class Coordinator: NSObject, WKURLSchemeHandler, WKNavigationDelegate {
        public let onSelect: (String) -> Void
        public var lastLoadedSVG: String = ""
        public var lastHighlightedID: String?
        public var pendingSelectedID: String?

        public init(onSelect: @escaping (String) -> Void) {
            self.onSelect = onSelect
        }

        // MARK: WKURLSchemeHandler

        public func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
            defer {
                // WKURLSchemeHandler requires a response + finish call.
                let response = URLResponse(
                    url: urlSchemeTask.request.url!,
                    mimeType: "text/plain",
                    expectedContentLength: 0,
                    textEncodingName: nil
                )
                urlSchemeTask.didReceive(response)
                urlSchemeTask.didReceive(Data())
                urlSchemeTask.didFinish()
            }

            guard let url  = urlSchemeTask.request.url,
                  url.host == "select"
            else { return }

            // Path is "/<id>" — drop the leading slash, percent-decode.
            let raw = String(url.path.dropFirst())
            let id  = raw.removingPercentEncoding ?? raw
            DispatchQueue.main.async { [weak self] in
                self?.onSelect(id)
            }
        }

        public func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {}

        // MARK: WKNavigationDelegate

        public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard let id = pendingSelectedID else { return }
            pendingSelectedID = nil
            lastHighlightedID = id
            webView.evaluateJavaScript(highlightJS(previousID: nil, newID: id),
                                       completionHandler: nil)
        }
    }

    // MARK: - HTML

    private func makeHTML(for svgContent: String) -> String {
        """
        <!DOCTYPE html>
        <html lang="en">
        <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <style>
            *, *::before, *::after { box-sizing: border-box; }
            html { height: 100%; background: #f5f5f5; }
            body { margin: 0; padding: 24px; background: #f5f5f5; }
            /* Each Verovio page rendered as a white card */
            .score-page {
              background: white;
              box-shadow: 0 1px 4px rgba(0,0,0,0.12);
              border-radius: 2px;
              margin-bottom: 20px;
              padding: 8px;
            }
            .score-page:last-child { margin-bottom: 0; }
            svg  { display: block; max-width: 100%; height: auto; }
            .sn-selected { filter: drop-shadow(0 0 3px rgba(0,112,255,0.8)); }
            .sn-selected * { fill: #0070ff !important; stroke: #0070ff !important; }
            g.note, g.rest, [class~="note"], [class~="rest"] { cursor: pointer; }
          </style>
        </head>
        <body>
        \(svgContent)
        <script>
        // Walk up from the click target looking for a note/rest id (our UUID scheme:
        // "n-<uuid>" or "r-<uuid>").  Filtering prevents accidentally firing on
        // Verovio's own system/measure group ids that appear above the note element.
        document.addEventListener('click', function(e) {
          var el = e.target;
          while (el && el.tagName !== 'BODY') {
            var id = el.getAttribute('id');
            if (id && (id.startsWith('n-') || id.startsWith('r-'))) {
              fetch('sn://select/' + encodeURIComponent(id)).catch(function(){});
              return;
            }
            el = el.parentElement;
          }
          fetch('sn://select/').catch(function(){});
        });
        </script>
        </body>
        </html>
        """
    }

    // MARK: - Highlight

    private func applyHighlight(webView: WKWebView, previousID: String?, newID: String?) {
        webView.evaluateJavaScript(highlightJS(previousID: previousID, newID: newID),
                                   completionHandler: nil)
    }
}

// MARK: - Highlight JS

private func highlightJS(previousID: String?, newID: String?) -> String {
    var js = ""
    if let old = previousID, !old.isEmpty {
        js += "{ var e = document.getElementById('\(old)'); if (e) e.classList.remove('sn-selected'); }\n"
    }
    if let new = newID, !new.isEmpty {
        js += "{ var e = document.getElementById('\(new)'); if (e) { e.classList.add('sn-selected'); e.scrollIntoView({ block: 'nearest', inline: 'nearest' }); } }\n"
    }
    return js.isEmpty ? "void 0;" : js
}
