//
//  NetworkInterface.swift
//  MachineInfo
//

import Foundation

/// One address on one interface.
public struct NetworkInterface: Codable, Sendable {

    /// The BSD name, e.g. `en0`.
    public let name: String
    /// The address, numeric.
    public let address: String
    /// `IPv4` or `IPv6`.
    public let family: String
    /// Whether this looks like the primary route out — the first
    /// non-loopback IPv4 on an `en` interface.
    public let isPrimary: Bool
}
