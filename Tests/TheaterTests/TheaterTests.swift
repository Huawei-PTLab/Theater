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

class TheaterTests: XCTestCase {
    func testParentChild() {
        let f = Family()
        sleep(1) //Wait for finish
        f.stop()

    }
    func testPingPong() {
        let pp = PingPong()
        sleep(3)
        pp.stop()
        sleep(1)    // wait for the stopping process to finish
    }

    func testGreetings() {
        let sys = GreetingActorController()
        sys.kickoff()
    }

    func testCloudEdge() {
        simpleCase(count:5)
    }

    static var allTests: [(String, (TheaterTests) -> () throws -> Void)] {
        return [
            ("testParentChild", testParentChild),
            ("testPingPong", testPingPong),
            ("testGreetings", testGreetings),
            ("testCloudEdge", testCloudEdge),
        ]
    }
}
