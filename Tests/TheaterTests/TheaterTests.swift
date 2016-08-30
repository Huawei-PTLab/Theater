//
// Copyright (c) 2016 Huawei PT-Lab Open Source project authors.
// Licensed under Apache License v2.0
//
// TheatorTests.swift
// Test driver for basic actor feature tests 
//

import XCTest
@testable import Theater

class TheaterTests: XCTestCase {
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
        let count = 1000
        let system = ActorSystem(name: systemName)
        let _ = system.actorOf({Server()}, name: serverName)
        let monitor = system.actorOf({Monitor()}, name: monitorName)
        for i in 0..<count {
            let client = system.actorOf({Client()}, name: "Client\(i)")
            let timestamp = timeval(tv_sec: 0, tv_usec:0)
            client ! Request(client: i, server: 0, timestamp: timestamp)
            usleep(1000)
        }
        sleep(10)
        monitor ! ShowResult(sender: nil)
        system.stop()
        sleep(2)    // wait to complete
    }

    static var allTests: [(String, (TheaterTests) -> () throws -> Void)] {
        return [
            ("testPingPong", testPingPong),
            ("testGreetings", testGreetings),
            ("testCloudEdge", testCloudEdge),
        ]
    }
}
