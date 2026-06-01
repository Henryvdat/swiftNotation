// RendererModel.swift
// ObservableObject that owns the single VerovioRenderer for the app session.

import Combine
import SwiftUI

final class RendererModel: ObservableObject {
    let verovio = VerovioRenderer()
}
