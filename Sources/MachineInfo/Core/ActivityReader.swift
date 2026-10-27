//
//  ActivityReader.swift
//  MachineInfo
//
//  Created by David Sherlock on 2026.
//
//  One reading of the running counters, straight from the kernel and IOKit:
//  per-core CPU ticks (host_processor_info), the block storage drivers'
//  byte counts, each interface's byte counts (getifaddrs), and each
//  readable process's CPU time and footprint (libproc). No process is
//  launched; a reading takes a few milliseconds.
//

import Darwin
import Foundation
import IOKit

enum ActivityReader {

    /// A reading now.
    static func read() -> ActivityReading {
        ActivityReading(cores: cores(), diskRead: disk().read, diskWrite: disk().write, interfaces: interfaces(),
                        processes: processes(), time: ProcessInfo.processInfo.systemUptime)
    }

    /// Each core's busy and idle ticks.
    static func cores() -> [(busy: UInt64, idle: UInt64)] {
        var count: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        guard host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &count, &info, &infoCount) == KERN_SUCCESS,
              let info else { return [] }
        defer { vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), vm_size_t(Int(infoCount) * MemoryLayout<integer_t>.stride)) }
        let states = Int(CPU_STATE_MAX)
        return (0..<Int(count)).map { core in
            let base = core * states
            let user = UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_USER)]))
            let system = UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_SYSTEM)]))
            let nice = UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_NICE)]))
            let idle = UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_IDLE)]))
            return (user + system + nice, idle)
        }
    }

    /// Bytes read and written by every block storage driver since boot.
    static func disk() -> (read: UInt64, write: UInt64) {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOBlockStorageDriver"), &iterator) == KERN_SUCCESS else {
            return (0, 0)
        }
        defer { IOObjectRelease(iterator) }
        var read: UInt64 = 0, write: UInt64 = 0
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            guard let stats = IORegistryEntryCreateCFProperty(service, "Statistics" as CFString, kCFAllocatorDefault, 0)?
                .takeRetainedValue() as? [String: Any] else { continue }
            read += (stats["Bytes (Read)"] as? NSNumber)?.uint64Value ?? 0
            write += (stats["Bytes (Write)"] as? NSNumber)?.uint64Value ?? 0
        }
        return (read, write)
    }

    /// Bytes received and sent on each link-level interface but loopback.
    static func interfaces() -> [String: (received: UInt32, sent: UInt32)] {
        var first: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&first) == 0, let first else { return [:] }
        defer { freeifaddrs(first) }
        var found: [String: (received: UInt32, sent: UInt32)] = [:]
        for pointer in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let entry = pointer.pointee
            guard let address = entry.ifa_addr, address.pointee.sa_family == UInt8(AF_LINK),
                  entry.ifa_flags & UInt32(IFF_LOOPBACK) == 0, let data = entry.ifa_data else { continue }
            let counters = data.assumingMemoryBound(to: if_data.self).pointee
            found[String(cString: entry.ifa_name)] = (counters.ifi_ibytes, counters.ifi_obytes)
        }
        return found
    }

    /// Each process this user may read: its name, CPU time and footprint.
    static func processes() -> [Int32: (name: String, cpuNanoseconds: UInt64, memoryBytes: Int64)] {
        var timebase = mach_timebase_info_data_t()
        mach_timebase_info(&timebase)
        let count = proc_listallpids(nil, 0)
        guard count > 0 else { return [:] }
        var pids = [pid_t](repeating: 0, count: Int(count) + 32)
        let filled = proc_listallpids(&pids, Int32(pids.count * MemoryLayout<pid_t>.stride))
        var found: [Int32: (name: String, cpuNanoseconds: UInt64, memoryBytes: Int64)] = [:]
        for pid in pids.prefix(Int(max(0, filled))) where pid > 0 {
            var usage = rusage_info_v2()
            let ok = withUnsafeMutablePointer(to: &usage) { pointer in
                pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { proc_pid_rusage(pid, RUSAGE_INFO_V2, $0) }
            }
            guard ok == 0 else { continue }
            var name = [CChar](repeating: 0, count: 256)
            proc_name(pid, &name, UInt32(name.count))
            let ticks = usage.ri_user_time + usage.ri_system_time
            let nanoseconds = ticks * UInt64(timebase.numer) / UInt64(max(1, timebase.denom))
            found[pid] = (String(cString: name), nanoseconds, Int64(usage.ri_phys_footprint))
        }
        return found
    }
}
