// swiftNotation-Bridging-Header.h
// Exposes Objective-C(++) types to Swift.
//
// VerovioWrapper is not thread-safe.  All calls to it must be serialised on
// a single DispatchQueue (see VerovioRenderer.swift).

#import "VerovioWrapper.h"
