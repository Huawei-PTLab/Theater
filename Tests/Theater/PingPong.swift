//
// Copyright (c) 2015 Dario Lencina and Huawei PT-Lab Open Source project authors.
// Licensed under Apache License v2.0
//
// PingPong.swift
// A simple example to test message deliver and actor system stop
//



import Foundation
import Theater
import Glibc

class Ball : Actor.Message {}

class Ping : Actor {
    
    var counter = 0
    
    override func receive(_ msg: Actor.Message) throws {
        switch(msg) {
            case is Ball:
                counter += 1
                print("ping counter: \(counter)")
                Thread.sleepForTimeInterval(1) //Never sleep in an actor, this is for demo!
                msg.sender! ! Ball(sender: this)
            
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
            print("pong counter: \(counter)")
            Thread.sleepForTimeInterval(1) //Never sleep in an actor, this is for demo!
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
        self.ping = system.actorOf({Ping()}, name: "ping")
        self.pong = system.actorOf({Pong()}, name: "pong")
        kickOffGame()
    }
    
    func kickOffGame() {
        pong ! Ball(sender: ping)
    }
    func stop() {
        system.stop();
    }

}


