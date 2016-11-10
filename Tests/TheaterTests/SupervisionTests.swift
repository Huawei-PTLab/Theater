//
// Copyright (c) 2016 Huawei PT-Lab Open Source project authors.
// Licensed under Apache License v2.0
//
// SupervisionTestse.swift
// Test case to check the basic supervision mechanism
//

import XCTest
import Foundation
@testable import Theater

class SupervisionTests: XCTestCase {

    static var allTests: [(String, (SupervisionTests) -> () throws -> Void)] {
        return [
            ("testUnexpectedMessageError", testUnexpectedMessageError),
            ("testRestart", testRestart),
            ("testEscalate", testEscalate),
        ]
    }

    func testUnexpectedMessageError() {
        let system = ActorSystem(name: "system")
        let a = system.actorOf(name:"DefaultSupervisor", DefaultSupervisor.init)
        // If test succeeds, error should be thrown and caught by "system/user"
        a ! Foo(sender: nil)
        sleep(1)
    }

    func testRestart() {
        let system = ActorSystem(name: "testRestart")
        let parent = system.actorOf(name: "supervisor",
                                    CounterActorSupervisor.init)
        parent ! CreateChild(sender: nil)
        sleep(1) // Wait the child to be created, otherwise the slectActor may get nothing
        let counter = system.actorFor("/user/supervisor/counter")
        for i in 1...10 {
            if i % 3 == 0 {
                // Once every 3 messages, send a Foo to trigger restart.
                print("sending message to reset counter")
                counter! ! Foo(sender: nil)
            } else {
                counter! ! Increment(sender: nil)
            }
            // we need to sleep between messages because supervisor needs time to react to the 
            // error messages from child
            usleep(100)
        }
        sleep(2)
    }

    func testEscalate() {
        let system = ActorSystem(name: "testRestart")
        let parent = system.actorOf(name: "supervisor",
                                    CounterActorSupervisor.init)
        parent ! CreateChild(sender: nil)
        sleep(1) // Wait the child to be created, otherwise the slectActor may get nothing
        let counter = system.actorFor("/user/supervisor/counter")
        for i in 1...10 {
            if i % 3 == 0 {
                print("triggering small error")
                counter! ! CommonError(sender: nil)
            } else if i == 6  {
                print("triggering fatal error")
                counter! ! FatalError(sender: nil)
            } else {
                counter! ! Increment(sender: nil)
            }
            // we need to sleep between messages because supervisor needs time to react to the 
            // error messages from child
            usleep(100)
        }
        sleep(2)
    }
}

class CreateChild: Actor.Message {}
class Foo: Actor.Message {}
class Increment: Actor.Message {}
class FatalError: Actor.Message {}
class CommonError: Actor.Message {}
enum TestError: Error {
    case CommonError
    case FatalError
}


class DefaultSupervisor: Actor {
    override func receive(_ msg: Actor.Message) throws -> Void {
        switch(msg) {
        default:
            throw TheaterError.unexpectedMessage(msg: msg)
        }
    }
}

class CounterActorSupervisor: Actor {
    override func supervisorStrategy(errorMsg: ErrorMessage) {
        switch (errorMsg.error) {
        case TestError.CommonError:
            errorMsg.sender!.restart()
        case TestError.FatalError:
            context.escalate()
        default:
            errorMsg.sender!.restart()
        }
    }
    override func receive(_ msg: Actor.Message) throws -> Void {
        switch(msg) {
        case is CreateChild:
            let _ = context.actorOf(name: "counter") {
                      (context:ActorCell) in
                         CounterActor(context:context, start: 0)
                    }
        default:
            throw TheaterError.unexpectedMessage(msg: msg)
        }
    }
}

class CounterActor: Actor {
    var counter: Int
    init(context:ActorCell, start: Int) {
        counter = start
        super.init(context:context)
    }
    override func receive(_ msg: Actor.Message) throws -> Void {
        switch(msg) {
        case is Increment:
            counter += 1
            print("counter: \(counter)")
        case is CommonError:
            throw TestError.CommonError
        case is FatalError:
            throw TestError.FatalError
        default:
            throw TheaterError.unexpectedMessage(msg: msg)
        }
    }
}
