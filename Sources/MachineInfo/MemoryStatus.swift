//
//  MemoryStatus.swift
//  MachineInfo
//
//  Created by David Sherlock on 2026.
//
//  How the memory is doing, from the Mach host statistics — the same
//  numbers Activity Monitor draws, without launching it.
//

import Darwin
import Foundation

/// Memory, in use and free.
public struct MemoryStatus: Codable, Sendable {

    /// Installed memory, in bytes.
    public let totalBytes: Int64
    /// Free plus inactive — what a new allocation can have without pressure.
    public let freeBytes: Int64
    /// Pages an app is actively using.
    public let activeBytes: Int64
    /// Pages the kernel will never page out.
    public let wiredBytes: Int64
    /// Pages held compressed.
    public let compressedBytes: Int64
    /// The kernel's pressure level — `normal`, `warning` or `critical` —
    /// where readable; `nil` on kernels that hide it.
    public let pressure: String?

    /// Reads the host's memory statistics, or `nil` if Mach refuses.
    public static func current() -> MemoryStatus? {
        var stats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        // `vm_kernel_page_size` is a mutable C global Swift 6 rejects; the
        // kernel publishes the same number as a sysctl.
        let page = Sysctl.integer("hw.pagesize") ?? 16_384
        let pressure: String?
        switch Sysctl.integer("kern.memorystatus_vm_pressure_level") {
        case 1: pressure = "normal"
        case 2: pressure = "warning"
        case 4: pressure = "critical"
        default: pressure = nil
        }
        return MemoryStatus(
            totalBytes: Sysctl.integer("hw.memsize") ?? 0,
            freeBytes: (Int64(stats.free_count) + Int64(stats.inactive_count)) * page,
            activeBytes: Int64(stats.active_count) * page,
            wiredBytes: Int64(stats.wire_count) * page,
            compressedBytes: Int64(stats.compressor_page_count) * page,
            pressure: pressure
        )
    }
}
