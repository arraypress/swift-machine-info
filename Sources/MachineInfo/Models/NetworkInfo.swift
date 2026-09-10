//
//  NetworkInfo.swift
//  MachineInfo
//
//  Created by David Sherlock on 2026.
//
//  The interfaces that are up, with their addresses. The Wi-Fi network's
//  name is included only when the system will give it without a location
//  permission — recent macOS ties the SSID to Location Services, and a
//  command-line tool should degrade to `nil` rather than demand it.
//

import CoreWLAN
import Darwin
import Foundation

/// The network as this machine sees it.
public struct NetworkInfo: Codable, Sendable {

    /// Every running, non-loopback address. Link-local IPv6 is left out.
    public let interfaces: [NetworkInterface]
    /// The Wi-Fi network's name, when the system shares it without a
    /// location permission.
    public let wifiSSID: String?

    /// Reads the interfaces and, where allowed, the Wi-Fi name.
    public static func current() -> NetworkInfo {
        var addresses: [(name: String, address: String, family: String)] = []
        var list: UnsafeMutablePointer<ifaddrs>?
        if getifaddrs(&list) == 0, let first = list {
            defer { freeifaddrs(list) }
            var cursor: UnsafeMutablePointer<ifaddrs>? = first
            while let entry = cursor {
                defer { cursor = entry.pointee.ifa_next }
                let flags = Int32(entry.pointee.ifa_flags)
                guard flags & IFF_UP != 0, flags & IFF_RUNNING != 0, flags & IFF_LOOPBACK == 0,
                      let sa = entry.pointee.ifa_addr else { continue }
                let family = sa.pointee.sa_family
                guard family == UInt8(AF_INET) || family == UInt8(AF_INET6) else { continue }
                var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                guard getnameinfo(sa, socklen_t(sa.pointee.sa_len), &host, socklen_t(host.count),
                                  nil, 0, NI_NUMERICHOST) == 0 else { continue }
                guard let address = Derive.cleanAddress(String(cString: host)) else { continue }
                addresses.append((String(cString: entry.pointee.ifa_name), address,
                                  family == UInt8(AF_INET) ? "IPv4" : "IPv6"))
            }
        }
        let primary = Derive.primary(of: addresses)
        let interfaces = addresses.map {
            NetworkInterface(name: $0.name, address: $0.address, family: $0.family,
                             isPrimary: $0.name == primary?.name && $0.address == primary?.address)
        }
        .sorted { ($0.name, $0.family, $0.address) < ($1.name, $1.family, $1.address) }
        return NetworkInfo(interfaces: interfaces, wifiSSID: CWWiFiClient.shared().interface()?.ssid())
    }
}
