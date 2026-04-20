//
//  main.swift
//  tunnel
//
//  Created by yiguo on 2026/4/18.
//

import Foundation
import NetworkExtension

Constants.useSystemExtension = true

autoreleasepool {
    NEProvider.startSystemExtensionMode()
}

dispatchMain()
