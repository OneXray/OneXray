#if DEBUG
import Foundation
import os

private let logger = Logger(subsystem: "net.yuandev.log", category: "debug")

func YGLog(_ message: String) {
    logger.error("\(message, privacy: .public)")
}

#else
func YGLog(_ message: String) {}
#endif
