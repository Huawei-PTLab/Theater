//
// Copyright (c) 2016 Huawei PT-Lab Open Source project authors.
// Licensed under Apache License v2.0
//
// TheatorTests.swift
// Test driver for basic actor feature tests
//

import XCTest
import Foundation
@testable import Theater

class ActorBenchTests: XCTestCase {
    func testChameneos() {
        chameneos(nChameneos:100000, nHost:4)
    }

    func testRing2() {
        ring2(nNodes:5, initValue:1000000)
    }

    func testFork() {
        fork(maxLevel:20)
    }

    static var allTests: [(String, (ActorBenchTests) -> () throws -> Void)] {
        return [
            ("testChameneos", testChameneos),
            ("testRing2", testRing2),
            ("testFork", testFork),
        ]
    }
}
