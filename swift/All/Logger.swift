#if DEBUG
import Foundation
import os

@available(macOS 11.0, iOS 14.0, watchOS 7.0, tvOS 14.0, *)
let logger = Logger(subsystem: "net.yuandev.log", category: "debug")

func YGLog(_ message: Any?) {
    if #available(macOS 11.0, iOS 14.0, watchOS 7.0, tvOS 14.0, *) {
        if let msg = message as? CustomDebugStringConvertible {
            logger.error("\(String(reflecting: msg), privacy: .public)")
        } else {
            logger.error("YGLog can not log object")
        }
    } else {
        if let msg = message as? CustomDebugStringConvertible {
            print(msg)
        } else {
            print("YGLog can not log object")
        }
    }
}

#else
func YGLog(_ message: Any?) {}
#endif
