// ScoreWebView.swift
// Renders an SVG string produced by Verovio inside a WKWebView.
//
// Entitlement note: com.apple.security.network.client is required by
// WKWebView's internal network sub-process even when no external requests
// are made by the application.

import SwiftUI
import WebKit

struct ScoreWebView: NSViewRepresentable {
    let svg: String

    // MARK: - NSViewRepresentable

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        // Transparent background so the SwiftUI window background shows through
        // when no score is loaded.  Using the public API instead of KVC.
        webView.underPageBackgroundColor = .clear
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        // Avoid reloading the web view if the SVG content has not changed.
        // WKWebView does not expose its current HTML, so we track it in the
        // Coordinator and compare before reloading.
        guard !svg.isEmpty, svg != context.coordinator.lastLoadedSVG else { return }
        context.coordinator.lastLoadedSVG = svg
        webView.loadHTMLString(makeHTML(for: svg), baseURL: nil)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    // MARK: - Coordinator

    final class Coordinator {
        /// The SVG string most recently loaded into the web view.
        var lastLoadedSVG: String = ""
    }

    // MARK: - HTML template

    private func makeHTML(for svgContent: String) -> String {
        """
        <!DOCTYPE html>
        <html lang="en">
        <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <style>
            *, *::before, *::after { box-sizing: border-box; }
            html, body {
              margin: 0;
              padding: 16px;
              background: white;
              font-family: sans-serif;
            }
            svg {
              max-width: 100%;
              height: auto;
              display: block;
            }
          </style>
        </head>
        <body>\(svgContent)</body>
        </html>
        """
    }
}
