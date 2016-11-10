//
// Copyright (c) 2016 Huawei PT-Lab Open Source project authors.
// Licensed under Apache License v2.0
//
// SelectActorTests.swift
// Test the feature that use a string path to find the right actor
//


import XCTest
import Foundation
@testable import Theater

class SelectActorTests: XCTestCase {

    static var allTests: [(String, (SelectActorTests) -> () throws -> Void)] {
        return [
            ("testFlat", testFlat),
            ("testNested", testNested),
            ("testFlatAndNested", testFlatAndNested),
            ("testActorForInActor", testActorForInActor),
        ]
    }

    func testFlat() {
        let system = ActorSystem(name: "system")
        let _ = system.actorOf(name: "Ping", Ping.init)
        let _ = system.actorOf(name: "Pong", Pong.init)

        let ping =  system.actorFor("/user/Ping")
        let pong =  system.actorFor("/user/Pong")
        XCTAssertNotNil(ping)
        XCTAssertNotNil(pong)
        pong! ! Ball(sender: ping)
        sleep(5)
        system.stop()
        sleep(2)
    }

    func testNested() {
        let system = ActorSystem(name: "system")
        let foo = system.actorOf(name: "Foo", PingParent.init)
        let bar = system.actorOf(name: "Bar", PongParent.init)
        foo ! Create(sender: nil)
        bar ! Create(sender: nil)
        sleep(1) //Wait until the two actors are created

        let ping = system.actorFor("/user/Foo/Ping")
        let pong = system.actorFor("/user/Bar/Pong")
        XCTAssertNotNil(ping)
        XCTAssertNotNil(pong)
        pong! ! Ball(sender: ping)
        sleep(5)
        system.stop()
        sleep(1)
    }

    func testFlatAndNested() {
        let system = ActorSystem(name: "system")
        let foo = system.actorOf(name: "Foo", PingParent.init)
        foo ! Create(sender: nil)
        sleep(1) //Wait until foo is created
        let _ = system.actorOf(name: "Pong", Pong.init)

        let ping = system.actorFor("/user/Foo/Ping")
        let pong = system.actorFor("/user/Pong")
        XCTAssertNotNil(ping)
        XCTAssertNotNil(pong)
        pong! ! Ball(sender: ping)
        sleep(5)
        system.stop()
        sleep(2)
    }

    func testActorForInActor() {
        let system = ActorSystem(name: "system")
        let _ = system.actorOf(name: "Ping", HeadlessPing.init)
        let _ = system.actorOf(name: "Pong", HeadlessPong.init)
        sleep(1) //Wati until actor is created
        let ping = system.actorFor("/user/Ping")
        XCTAssertNotNil(ping)
        ping! ! Ball(sender: nil)
        sleep(5)
        system.stop()
        sleep(2)
    }
}

class Create: Actor.Message {}

class PingParent: Actor {
    override func receive(_ msg: Actor.Message) {
        switch(msg) {
        case is Create:
            let _ = context.actorOf(name: "Ping", Ping.init)
        default:
            print("unexpected message")
        }
    }
}

class PongParent: Actor {
    override func receive(_ msg: Actor.Message) {
        switch(msg) {
        case is Create:
            let _  = context.actorOf(name: "Pong", Pong.init)
        default:
            print("unexpected message")
        }
    }
}

class HeadlessPing : Actor {
    var counter = 0
    
    override func receive(_ msg: Actor.Message) throws {
        switch(msg) {
            case is Ball:
                counter += 1
                print("ping counter: \(counter)")
                Thread.sleep(forTimeInterval: 1) //Never sleep in an actor, this is for demo!
                let selected = context.actorFor("/user/Pong")
                if let pong = selected {
                    pong ! Ball(sender: nil)
                }
            default:
                try super.receive(msg)
        }
    }
}

class HeadlessPong : Actor {
    var counter = 0
    
    override func receive(_ msg: Actor.Message) throws {
        switch(msg) {
        case is Ball:
            counter += 1
            print("pong counter: \(counter)")
            Thread.sleep(forTimeInterval: 1) //Never sleep in an actor, this is for demo!
            let selected =  context.actorFor("/user/Ping")
            if let ping = selected {
                ping ! Ball(sender: nil)
            }
        default:
            try super.receive(msg)
        }
    }
}
