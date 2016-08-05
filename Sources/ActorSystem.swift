//
//  ActorContext.swift
//  Actors
//
//  Created by Dario Lencina on 9/27/15.
//  Copyright © 2015 dario. All rights reserved.
//

import Foundation
import Dispatch


/**
	All actors live in 'ActorSystem'.

	You might have more than 1 actor system.
*/
public class ActorSystem  {
    
    lazy private var supervisor: ActorRef = Actor.createSupervisorActor(name: self.name, context: self)

    /**
		The name of the 'ActorSystem'
    */
	private let name : String

	private let dispatcher: Dispatcher

    /**
		Create a new actor system
     
		- parameter name : The name of the ActorSystem
    */
    public init(name : String, dispatcher: Dispatcher = DefaultDispatcher()) {
        self.name = name
		self.dispatcher = dispatcher
    }

	internal func assignQueue() -> dispatch_queue_t {
		return dispatcher.assignQueue()
	}
    
    /**
		This is used to stop or kill an actor
     
		- parameter actorRef : the actorRef of the actor that you want to stop.
    */
    public func stop(_ actorRef : ActorRef) -> Void {
        // supervisor!.stop(actorRef)	//TODO
    }
    
	//TODO
    public func stop() {
		supervisor ! Actor.Harakiri(sender: nil)
    }
    
    /**
    This method is used to instantiate actors using an Actor class as the 'blueprint' and assigning a unique name to it.
     
    - parameter clz: Actor Class
    - parameter name: name of the actor, it has to be unique
    - returns: Actor ref instance
     
     ## Example
     
     ```
     var wsCtrl : ActorRef = actorSystem.actorOf(WSRViewController.self, name:  "WSRViewController")
     ```
    */
    public func actorOf(_ actorInstance : Actor, name : String) -> ActorRef {
        return supervisor.actorInstance.actorOf(actorInstance, name: name)
    }
    
    /**
     This method is used to instantiate actors using an Actor class as the 'blueprint' and assigning a unique name to it.
     
     - parameter clz: Actor Class
     - returns: Actor ref instance with a random UUID as name
     
      ##Example:
     
     ```
     var wsCtrl : ActorRef = actorSystem.actorOf(WSRViewController.self)
     ```
     
    */
    public func actorOf(_ actorInstance : Actor) -> ActorRef {
		return supervisor.actorInstance.actorOf(actorInstance)
    }
    
    public func selectActor(_ actorPath : String) -> Optional<ActorRef>{
		return try? self.supervisor.actorInstance.selectActor(pathString: actorPath)
    }
    
    deinit {
        #if DEBUG
            print("killing ActorSystem: \(name)")
        #endif
    }
}

/**
The first rule about actors is that you should not access them directly, you always talk to them through it's ActorRef, but for testing sometimes is really convenient to just get the actor and inspect it's properties, that is the reason why we provide 'TestActorSystem' please do not use it in your AppCode, only in tests.
*/

public class TestActorSystem : ActorSystem {
}
