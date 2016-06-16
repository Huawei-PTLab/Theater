//
//  GreetingActor.swift
//  Actors
//
//  Created by Dario Lencina on 11/9/15.
//  Copyright © 2015 dario. All rights reserved.
//

import Foundation
import Theater
import Glibc

class Greeting : Actor.Message {}
class Angry : Actor.Message {}
class Happy : Actor.Message {}

class GreetingActor: Actor {

    required init(context: ActorSystem, ref: ActorRef) {
        super.init(context: context, ref: ref)
    }

    override func preStart() -> Void {
        super.preStart()
        self.become("happy", state: self.happy(), discardOld: true)
    }

    /**
     Pop states from the statesStack until it finds name
     - Parameter name: the state that you can to pop to.
     */
    override func popToState(name : String) -> Void {
        if let (hName, _ ) = self.statesStack.head() {

            //if hName != name && hName != self.withCtrlState {
            if hName != name  {
                unbecome()
                popToState(name: name)
            }
        } else {
            print("unable to find state with name \(name)")
        }
    }

    func happy() -> Receive { return {[unowned self](msg : Message) in
            switch(msg) {
            case is Greeting:
                print("Actor says: Hello")
            case is Angry:
                print("Actor is Angry")
                self.become("angry", state: self.angry(), discardOld: true)
            default:
                self.receive(msg)
            }
        }
    }

    func angry()  -> Receive { return {[unowned self](msg : Message) in
            switch(msg) {
            case is Greeting:
                print("Actor says: Go away")
            case is Happy:
                print("Actor is happy")
                self.become("happy", state: self.happy(), discardOld: true)
            default:
                self.receive(msg)
            }
        }
    }

}

class GreetingActorController {
    lazy var system : ActorSystem = ActorSystem(name : "GreetingActorController")
    lazy var greetingActor : ActorRef = self.system.actorOf(GreetingActor.self, name:"GreetingActor")

    func kickoff(){
        greetingActor ! Greeting(sender: nil)
        greetingActor ! Happy(sender: nil)
        greetingActor ! Angry(sender: nil)
        greetingActor ! Greeting(sender: nil)
        greetingActor ! Greeting(sender: nil)
        greetingActor ! Happy(sender: nil)
        greetingActor ! Greeting(sender: nil)
        sleep(10)
    }
}
let sys = GreetingActorController()
sys.kickoff()
