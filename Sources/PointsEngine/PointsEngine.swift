import Foundation
import Core

public final class PointsEngine {
    public init() {}
    public func accrue(pointsPerMinute: Int, minutes: Int) -> Int { max(0, pointsPerMinute * minutes) }
}

