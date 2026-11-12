import AppKit
import Darwin
#if SWIFT_PACKAGE
import MarbleCore
#endif

@main
enum Entry {
    static func main() {
        if CommandLine.arguments.contains("--mock-benchmark") { MockBenchmark.run(); return }
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.setActivationPolicy(.accessory); app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}

/// Automated performance harness: fake backend, no NativeInput/IOKit/UI/TCC construction.
private enum MockBenchmark {
    final class Backend: InputBackend {
        func start() throws {}
        func stop() {}
        func recover() throws {}
    }
    static func run() {
        var settings = Settings(); settings.button = 3
        let session = Session(settings: settings, backend: Backend(), permission: { true }, device: { true })
        var before = rusage(); getrusage(RUSAGE_SELF, &before)
        let idleStart = ProcessInfo.processInfo.systemUptime
        // A single timed wait represents an idle event loop. No polling, no input APIs.
        let semaphore = DispatchSemaphore(value: 0)
        _ = semaphore.wait(timeout: .now() + 5)
        var afterIdle = rusage(); getrusage(RUSAGE_SELF, &afterIdle)
        let idleResident = residentMiB()
        let idleSeconds = ProcessInfo.processInfo.systemUptime - idleStart
        try! session.start(liveAuthorized: true, globalConsent: true)
        _ = session.handle(Input(.down(3), at: 10))
        let start = ProcessInfo.processInfo.systemUptime
        let count = 1_000_000
        var outputChecksum: Int64 = 0
        for i in 0..<count {
            _ = session.route(Input(.move(Delta(1, 2)), at: 10.2 + Double(i) / 1000)) { pixels in
                outputChecksum &+= Int64(pixels.horizontal) + Int64(pixels.vertical)
                return true
            }
        }
        let elapsed = ProcessInfo.processInfo.systemUptime - start
        session.stop(.terminating)
        var final = rusage(); getrusage(RUSAGE_SELF, &final)
        func cpu(_ u: rusage) -> Double {
            Double(u.ru_utime.tv_sec + u.ru_stime.tv_sec) + Double(u.ru_utime.tv_usec + u.ru_stime.tv_usec) / 1e6
        }
        let idleCPU = max(0, cpu(afterIdle) - cpu(before)) / idleSeconds * 100
        print("MOCK ONLY: no native tap, HID input, permission request, UI or installation")
        print(String(format: "idle_wall_seconds=%.3f idle_cpu_percent=%.4f resident_mib=%.2f resource_maxrss_mib=%.2f", idleSeconds, idleCPU, idleResident, Double(afterIdle.ru_maxrss) / 1048576))
        print(String(format: "mock_events=%d elapsed_seconds=%.4f mean_us_per_event=%.4f final_resident_mib=%.2f checksum=%lld", count, elapsed, elapsed * 1e6 / Double(count), residentMiB(), outputChecksum))
    }
    private static func residentMiB() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? Double(info.resident_size) / 1048576 : -1
    }
}
