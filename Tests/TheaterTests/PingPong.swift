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
            print("Pong counter: \(counter)")
            //Never sleep in an actor, this is for demo!
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
        self.ping = system.actorOf(Ping.init, name: "ping")
        self.pong = system.actorOf(Pong.init, name: "pong")
        kickOffGame()
    }
    
    func kickOffGame() {
        pong ! Ball(sender: ping)
    }
    func stop() {
        system.stop();
    }

}


