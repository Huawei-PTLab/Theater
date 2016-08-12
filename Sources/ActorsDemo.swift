//
//  ActorsDemo.swift
//  Actors
//
//  Created by Dario Lencina on 9/26/15.
//  Copyright © 2015 dario. All rights reserved.
//

import Foundation
import XCTest

public class TestPerformance : Actor.Message {
    public let count : Int
    public let max : Int
    public let expectation : XCTestExpectation

    
    public init(sender : ActorRef, count : Int, max : Int, expectation : XCTestExpectation) {
        self.count = count
        self.max = max
        self.expectation = expectation
        super.init(sender : sender)
    }
}

public class TestActor : Actor {
    override public func receive(_ msg : Actor.Message) -> Void {
        switch msg {
        case is TestPerformance:
                let test = msg as! TestPerformance
                print("got message in TestActor")
                if test.count > test.max {
                    print("The end")
                    test.expectation.fulfill()
                } else {
                    if let sender = msg.sender {
                        sender ! TestPerformance(sender: this, count: test.count + 1, max: test.max, expectation: test.expectation)
                    }
                }
                break
            default :
            print("I do not know what you're talking about")
        }
    }
}
