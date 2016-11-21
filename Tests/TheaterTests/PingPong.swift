//
// Copyright (c) 2015 Dario Lencina and Huawei PT-Lab Open Source project authors.
// Licensed under Apache License v2.0
//
// PingPong.swift
// A simple example to test message deliver and actor system stop
//



import Foundation
import Theater

class Ball : Actor.Message {}

class Ping : Actor {
    
    var counter = 0
    
    override func receive(_ msg: Actor.Message) throws {
        switch(msg) {
            case is Ball:
                counter += 1
                print("Ping counter: \(counter)")
                //Never sleep in an actor, this is for demo!
                Thread.sleep(forTimeInterval: 1)
                //Never sleep in an actor, this is for demo!
                if counter == 3 {
                    context.system.shutdown()
                } else {
                  msg.sender! ! Ball(sender: this)
                }
            default:
                try super.receive(msg)
        }
    }
}

class Pong : Actor {
    var counter = 0
    
    override func receive(_ msg: Actor.Message) throws {
        switch(msg) {
        case is Ball:
            counter += 1
            print("Pong counter: \(counter)")
            Thread.sleep(forTimeInterval: 1)
            msg.sender! ! Ball(sender: this)
            
        default:
            try super.receive(msg)
        }
    }
}

public class PingPong {
    
    let system = ActorSystem(name: "pingpong")
    let ping : ActorRef
    let pong : ActorRef
    
    public init() {
        self.ping = system.actorOf(name: "ping", Ping.init)
        self.pong = system.actorOf(name: "pong", Pong.init)
        pong ! Ball(sender: ping)
    }

    func waitforStop() {
        _ = self.system.waitFor(seconds:20)
    }

}


