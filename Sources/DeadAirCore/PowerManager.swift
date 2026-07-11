import Foundation
import IOKit.pwr_mgt

public final class PowerManager: @unchecked Sendable {
    private var assertionID = IOPMAssertionID(0)
    private var activityToken: NSObjectProtocol?
    private let lock = NSLock()

    public init() {}

    public func arm() {
        lock.lock()
        defer { lock.unlock() }

        guard assertionID == 0 else { return }
        var newAssertion = IOPMAssertionID(0)
        let status = IOPMAssertionCreateWithName(
            kIOPMAssertionTypeNoIdleSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "Dead Air show mode" as CFString,
            &newAssertion
        )
        if status == kIOReturnSuccess {
            assertionID = newAssertion
        }

        activityToken = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .idleSystemSleepDisabled],
            reason: "Dead Air show mode"
        )
        Diagnostics.shared.record(LogEvent(source: "power", message: "show mode power assertions armed"))
    }

    public func disarm() {
        lock.lock()
        defer { lock.unlock() }

        if assertionID != 0 {
            IOPMAssertionRelease(assertionID)
            assertionID = 0
        }

        if let activityToken {
            ProcessInfo.processInfo.endActivity(activityToken)
            self.activityToken = nil
        }
        Diagnostics.shared.record(LogEvent(source: "power", message: "show mode power assertions released"))
    }

    deinit {
        // Safety net: never leak the no-sleep assertion if an owner is
        // released without an explicit disarm on some exit path.
        disarm()
    }
}
