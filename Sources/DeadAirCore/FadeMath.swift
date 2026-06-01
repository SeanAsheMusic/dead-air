import Foundation

public enum FadeMath {
    public static func equalPower(_ t: Double) -> Double {
        sin((max(0, min(1, t)) * .pi) / 2.0)
    }

    public static func dbToLinear(_ db: Double) -> Float {
        Float(pow(10.0, db / 20.0))
    }

    public static func linearToDb(_ value: Float) -> Double {
        guard value > 0 else { return -96 }
        return 20.0 * log10(Double(value))
    }
}
