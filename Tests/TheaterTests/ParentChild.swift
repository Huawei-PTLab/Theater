//
// Copyright (c) 2016 Huawei PT-Lab Open Source project authors.
// Licensed under Apache License v2.0
//
// ParentChild.swift
// A simple example to test message deliver and actor system stop
//



import Foundation
import Theater

class Love : Actor.Message {}


class Child : Actor {
    override func receive(_ msg: Actor.Message) throws {
      switch(msg) {
      case is Love:
          print("\(this) receives love from \(msg.sender!)")
          msg.sender! ! Love(sender: this)
      default:
          print("\(this) receives wrong msg")
      }
    }
}

class Parent : Actor {

    var son: ActorRef!
    var daughter: ActorRef!

    override init(context:ActorCell) {
        son = context.actorOf(name:"son", Child.init)
        daughter = context.actorOf(name:"daughter", Child.init)
        super.init(context:context)
    }
    
    override func receive(_ msg: Actor.Message) throws {
        switch(msg) {
            case is Love:
                print("\(this) receives love from \(msg.sender!)")
            default:
                son ! Love(sender:this)
                daughter ! Love(sender:this)
        }
    }
}

public class Family {
    
    let system = ActorSystem(name: "Family")
    let parent : ActorRef
    
    public init() {
        parent = system.actorOf(name: "Parent", Parent.init)
        parent ! Actor.Message(sender:nil)
    }

    func stop() {
        system.shutdown();
    }

}


