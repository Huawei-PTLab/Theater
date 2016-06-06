//
//  PingPong.swift
//  Actors
//
//  Created by Dario Lencina on 11/9/15.
//  Copyright © 2015 dario. All rights reserved.
//

import Foundation
import Theater

class Rsp : Actor.Message {
    let src_no : Int
    let tgt_no : Int

    init(sender : ActorRef, src_no : Int, tgt_no : Int) {
        self.src_no = src_no
        self.tgt_no = tgt_no
        super.init(sender : sender)
    }

}
class InitSys : Actor.Message {}
class Greeting : Actor.Message {
    let src_no : Int
    let tgt_no : Int

    init(sender : ActorRef, src_no : Int, tgt_no : Int) {
        self.src_no = src_no
        self.tgt_no = tgt_no
        super.init(sender : sender)
    }

}
class Angry : Actor.Message {
    let src_no : Int
    let tgt_no : Int

    init(sender : ActorRef, src_no : Int, tgt_no : Int) {
        self.src_no = src_no
        self.tgt_no = tgt_no
        super.init(sender : sender)
    }

}
class Happy : Actor.Message {
    let src_no : Int
    let tgt_no : Int

    init(sender : ActorRef, src_no : Int, tgt_no : Int) {
        self.src_no = src_no
        self.tgt_no = tgt_no
        super.init(sender : sender)
    }
}

class GreetingActor : Actor {

    override func receive(_ msg: Actor.Message) {
        switch(msg) {
            case is InitSys:
                self.happy()(msg)
            default:
                super.receive(msg)
        }
    }

    func happy() -> (Actor.Message) -> Void { return {(msg : Actor.Message) in
            switch(msg) {
                case is InitSys:
					self.unbecome()
                    self.become("happy", state: self.happy())
                case is Greeting:
                    print("say Hello")

                case is Angry:
                    print("Happy -> Angry")
                    self.unbecome()
                    self.become("angry", state: self.angry())
                case is Happy:
                     print("Happy -> Happy")
                default:
                    print("msg is no")
            }
        }
    }
    func angry()  -> (Actor.Message) -> Void { return {(msg : Actor.Message) in
            switch(msg) {
                case is Greeting:
                    print("Go away")
                case is Happy:
                    print("Angry -> Happy")
                    self.unbecome()
					self.become("happy", state: self.happy())

                    //self.reply()
                case is Angry:
                    print("Angry -> Angry")
                default:
                    print("msg is no")
            }
        }
    }
    func reply(src_no: Int, tgt_no: Int){
        let rsp = Rsp(sender: this, src_no: src_no, tgt_no: tgt_no)
        self.sender! ! rsp
    }

}
class Greeter : Actor{
    override func receive(_ msg: Actor.Message) {
        switch(msg) {
            case is Rsp:
                let rsp = msg as? Rsp
                print("Greeter \(rsp!.src_no), receive rsp from \(rsp!.tgt_no)")
            default:
                super.receive(msg)
        }
    }
}
public class GreetingActorController {

    let system = ActorSystem(name: "GreetingActorController")
    let greeter : ActorRef
    let greetingActor : ActorRef

    public init() {
        self.greeter = system.actorOf(Greeter.self, name: "greeter")
        self.greetingActor = system.actorOf(GreetingActor.self, name: "greetingActor")
        //kickOffGame()
    }
    func kickOffGame() {
        print("src_no 1")
        test1()
    }
    func test1(){
        initSys()
        sendHappy(sender:greeter,src_no:1, tgt_no: 2)
        NSThread.sleepForTimeInterval(3)
        sayHi(sender:greeter,src_no:1, tgt_no: 2)
        NSThread.sleepForTimeInterval(3)
        sendAngry(sender:greeter,src_no:1, tgt_no: 2)
        NSThread.sleepForTimeInterval(3)
        sayHi(sender:greeter,src_no:1, tgt_no: 2)
        NSThread.sleepForTimeInterval(3)
        sendAngry(sender:greeter,src_no:1, tgt_no: 2)
        NSThread.sleepForTimeInterval(3)
        sendHappy(sender:greeter,src_no:1, tgt_no: 2)
        NSThread.sleepForTimeInterval(3)
        sayHi(sender:greeter,src_no:1, tgt_no: 2)
    }
    func initSys(){
        greetingActor ! InitSys(sender: greeter)
    }
    func sayHi(sender : ActorRef, src_no : Int, tgt_no : Int) {
        let msg = Greeting(sender: sender, src_no: src_no, tgt_no: tgt_no)
        greetingActor ! msg
    }
    func sendAngry(sender : ActorRef, src_no : Int, tgt_no : Int) {
        let msg = Angry(sender: sender, src_no: src_no, tgt_no: tgt_no)
        greetingActor ! msg
    }
    func sendHappy(sender : ActorRef, src_no : Int, tgt_no : Int) {
        let msg = Happy(sender: sender, src_no: src_no, tgt_no: tgt_no)
        greetingActor ! msg
    }

    func stop() {
        system.stop();
    }
}
let sys = GreetingActorController()
sys.kickOffGame()
