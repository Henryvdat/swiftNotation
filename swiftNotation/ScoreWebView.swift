// ScoreWebView.swift
// Renders an SVG string produced by Verovio inside a WKWebView.
// Requires com.apple.security.network.client entitlement for WKWebView's
// internal network process (no external requests are made by the app).

import SwiftUI
import WebKit

struct ScoreWebView: NSViewRepresentable {
    let svg: String

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.setValue(false, forKey: "drawsBackground")
        return wv
    }

    func updateNSView(_ wv: WKWebView, context: Context) {
        guard !svg.isEmpty else { return }
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="UTF-8">
        <style>
          html, body { margin: 0; padding: 16px; background: white; }
          svg { max-width: 100%; height: auto; display: block; }
        </style>
        </head>
        <body>\(svg)</body>
        </html>
        """
        wv.loadHTMLString(html, baseURL: nil)
    }
}
