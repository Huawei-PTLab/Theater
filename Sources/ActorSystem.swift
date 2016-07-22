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
An actor system has a tree like structure, ActorPath gives you an url like way to find an actor inside a given actor system.

@warning: We still do not support multiple levels of actors. Currently all actors are direct children of the ActorSystem that it belongs to.
*/

public class ActorPath {
    
    public let asString : String
    
    public init(path : String) {
        self.asString = path
    }
}

/**
'ActorRef' provides a reference to a given 'Actor', you should always talk to actors though it's ActorRef.
*/

public class ActorRef : CustomStringConvertible {
    
	public var description: String {
		get {
			return "<\(self.dynamicType): \(path.asString)>"
		}
	}
    
    /**
    The actor system that this ActorRef belongs to
    */
    
    public let context : ActorSystem
    
    /**
     The Path to this ActorRef
     */
    
    public let path : ActorPath

	/**
	 * Reference to the actual actor. 
	 * Set in Actor init() and unset in deinit()
	 * Use weak to break cycle between Actor and ActorRef
	 */
	internal weak var actorInstance: Actor? = nil
    
    /**
    This constructor is used by the ActorSystem, should not be used by developers
    */
    
    public init(context : ActorSystem, path : ActorPath) {
        self.context = context
        self.path = path
    }
    
    /**
    This method is used to send a message to the underlying Actor.
     
    - parameter msg : The message to send to the Actor.
    */

    public func tell (_ msg : Actor.Message) -> Void {
        self.context.tell(msg, recipientRef:self)
    }
    
}

/**
The first rule about actors is that you should not access them directly, you always talk to them through it's ActorRef, but for testing sometimes is really convenient to just get the actor and inspect it's properties, that is the reason why we provide 'TestActorSystem' please do not use it in your AppCode, only in tests.
*/

public class TestActorSystem : ActorSystem {
}

/**

All actors live in 'ActorSystem'.

You might have more than 1 actor system.

For convenience, we provide AppActorSystem.shared which provides a default actor system.

*/

public class ActorSystem  {
    
    lazy private var supervisor : Actor? = Actor.self.init(context: self, ref: ActorRef(context: self, path: ActorPath(path: "\(self.name)/user")))

	private let systemQueue = dispatch_queue_create("system", nil)
	private var queues = [dispatch_queue_t]()
	private var randomQueue: dispatch_queue_t? = nil
	private let maxQueues: Int
	private var queueCount = 0
    
    
    /**
     
    The name of the 'ActorSystem'
     
    */
    
    let name : String
    
    /**
    Create a new actor system
     
    - parameter name : The name of the ActorSystem
    */
    
    public init(name : String, maxQueues: Int = 1000) {
        self.name = name
		self.maxQueues = maxQueues
		srandom(UInt32(NSDate().timeIntervalSince1970))
    }

	func getQueue() -> dispatch_queue_t {
		if queueCount < maxQueues {
			let newQueue = dispatch_queue_create("", nil)
			if randomQueue == nil { randomQueue = newQueue }
			queueCount += 1
			dispatch_async(systemQueue) { () in 
				self.queues.append(newQueue)
				let randomNumber = Int(rand())
				if randomNumber % 2 == 0 {
					self.randomQueue = newQueue
				}
			}
			return newQueue
		} else {
			dispatch_async(systemQueue) { () in 
				let randomNumber = Int(rand()) % self.maxQueues
				self.randomQueue = self.queues[randomNumber]
			}
			return randomQueue!
		}
	}
    
    /**
    This is used to stop or kill an actor
     
    - parameter actorRef : the actorRef of the actor that you want to stop.
    */
    
    public func stop(_ actorRef : ActorRef) -> Void {
        supervisor!.stop(actorRef)
    }
    
    public func stop() {
        supervisor!.stop()
        //TODO: there must be a better way to wait for all actors to die...
        func shutdown(){
            // dispatch_after(5000, NSOperationQueue.mainQueue().underlyingQueue!) {[unowned self] () -> Void in
            //     if(self.supervisor!.children.count == 0) {
            //         self.supervisor = nil
            //     }
            // }
            sleep(5)
			// TODO: not properly stop
            // if(self.supervisor!.children.count == 0) {
            //         self.supervisor = nil
            // }
        }
        shutdown()
        
        
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
    
    public func actorOf(_ clz : Actor.Type, name : String) -> ActorRef {
        return supervisor!.actorOf(clz, name: name)
    }

	public func actorOf(_ clz: Actor.Type, name: String, args: [Any]! = nil) -> ActorRef {
		return supervisor!.actorOf(clz, name: name, args: args)
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
    
    public func actorOf(_ clz : Actor.Type) -> ActorRef {
        return actorOf(clz, name: NSUUID.init().UUIDString)
    }
    
    /**
    This method tries finding an actor given it's actorpath as a string
     
    - Parameter actorPath : the actor path as string
    - returns : an ActorRef or None
    */
    
    public func selectActor(_ actorPath : String) -> Optional<ActorRef>{
		dispatch_barrier_sync(self.supervisor!.underlyingQueue) { () in
			// nothing, wait for enqueued changes to complete
		}
		//TODO: needs to find actors that are NOT attached to supervisor
        return self.supervisor!.children[actorPath].map({ (a : Actor) -> ActorRef in return a.this})
    }
    
    /**
    All messages go through this method, eventually we will create an scheduler
     
    - parameter msg : message to send
    - parameter recipient : the ActorRef of the Actor that you want to receive the message.
    */
    
    public func tell(_ msg : Actor.Message, recipientRef : ActorRef) -> Void {
        
		if let actor = recipientRef.actorInstance {
			actor.tell(msg)
		} else {
            #if DEBUG
                print("Dropped message \(msg)")
            #endif
			print("[WARNING] fail to deliver message \(msg) to \(recipientRef.path.asString)")
        }
    }
    
    deinit {
        #if DEBUG
            print("killing ActorSystem: \(name)")
        #endif

    }
}
