// VerovioScoreRenderer.swift
// Conformance of VerovioRenderer to the NotationEditor.ScoreRenderer protocol.
//
// VerovioRenderer already implements all required methods (load, renderPage,
// setOptions, pageCount) — this extension just declares the conformance.

import NotationEditor

extension VerovioRenderer: NotationEditor.ScoreRenderer {}
