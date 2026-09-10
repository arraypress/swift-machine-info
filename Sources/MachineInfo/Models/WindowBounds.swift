//
//  WindowBounds.swift
//  MachineInfo
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// A window's frame in points, in the window server's coordinates: the
/// origin is the top-left of the main display, and y grows downward.
///
/// Not a `CGRect`, so the JSON reads `x, y, width, height` rather than
/// nested `origin`/`size` pairs a consumer has to know the shape of.
public struct WindowBounds: Codable, Sendable, Equatable {

    /// Left edge.
    public let x: Double

    /// Top edge.
    public let y: Double

    /// Width in points.
    public let width: Double

    /// Height in points.
    public let height: Double

    /// A frame from its four numbers.
    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}
