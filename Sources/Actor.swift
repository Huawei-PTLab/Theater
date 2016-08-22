//
//  Actor.swift
//  Actors
//
//  Created by Dario Lencina on 9/26/15.
//  Copyright © 2015 dario. All rights reserved.
//

import Foundation
import Dispatch
infix operator ! {associativity left precedence 130}

/**
 
 '!' Is a shortcut for typing:
 
 ```
 actor ! msg
 ```
 
 instead of
 
 ```
 actorRef.tell(msg)
 ```
 
 */

public func !(actorRef : ActorRef, msg : Actor.Message) -> Void {
	let unmanaged = Unmanaged.passRetained(msg)
    actorRef.tell(unmanaged)
}

public typealias Receive = (Actor.Message) -> (Void)

/**

'Actor'

Actors are the central elements of Theater.

## Subclassing notes

You must subclass Actor to implement your own actor classes such as: BankAccount, Device, Person etc.

the single most important to override is
 
```
public func receive(msg : Actor.Message) -> Void
```
 
Which will be called when some other actor tries to ! (tell) you something

*/

public class Actor : NSObject {
    
    public func stop() {
        this ! Harakiri(sender:nil)
    }
    
    public func stop(_ actorRef : ActorRef) -> Void {
        // self.mailbox.addOperationWithBlock { () -> Void in
        //     let path = actorRef.path.asString
        //     self.children.removeValueForKey(path)
		// TODO: not properly stop
        underlyingQueue.async { () -> Void in
            let path = actorRef.path.asString
            self.children.removeValue(forKey: path)
        }
    }
    
    public func actorOf(_ clz : Actor.Type) -> ActorRef {
        return actorOf(clz, name: NSUUID.init().UUIDString)
    }

    public func actorOf(_ clz : Actor.Type, name : String) -> ActorRef {
        //TODO: should we kill or throw an error when user wants to reuse address of actor?
        let completePath = "\(self.this.path.asString)/\(name)"
        let ref = ActorRef(context:self.context, path:ActorPath(path:completePath))
		let actorInstance: Actor = clz.init(context: self.context, ref: ref)
		underlyingQueue.async { () in 
			self.children[completePath] = actorInstance
		}
        return ref
    }

	/*
	 * Pass parameters to Actor constructor
	 */
	public func actorOf(_ clz: Actor.Type, name: String, args: [Any]! = nil) -> ActorRef {
		let completePath = "\(self.this.path.asString)/\(name)"
		let ref = ActorRef(context: self.context, path: ActorPath(path: completePath))
		let actorInstance: Actor = clz.init(context: self.context, ref: ref, args: args)
		underlyingQueue.async { () in
			self.children[completePath] = actorInstance
		}
		return ref
	}
    
    /**
     
     */
    
    final var children  = [String : Actor]()
    
    public func getChildrenActors() -> [String: ActorRef] {
        var newDict : [String:ActorRef] = [String : ActorRef]()
        
        for (k,v) in self.children {
            newDict[k] = v.this
        }
        return newDict
    }
    
    /**
    Here we save all the actor states
    */
    
    final public let statesStack : Stack<(String,Receive)> = Stack()
    
    /**
    Each actor has it's own mailbox to process Actor.Messages.
    */
    
    //final public let mailbox : NSOperationQueue = NSOperationQueue()
    final public let underlyingQueue: DispatchQueue 
    
    /**
    Sender has a reference to the last actor ref that sent this actor a message
    */
    
    // public var sender : Optional<ActorRef>
    
    /**
    Reference to the ActorRef of the current actor
    */
    
    public let this : ActorRef
    
    /**
    Context refers to the Actor System that this actor belongs to.
    */
    
    public let context : ActorSystem
    
    /**
    Actors can adopt diferent behaviours or states, you can "push" a new state into the statesStack by using this method.
    
    - Parameter state: the new state to push
    - Parameter name: The name of the new state, it is used in the logs which is very useful for debugging
    */
    
    final public func become(_ name : String, state : Receive) -> Void  {
        become(name, state : state, discardOld : false)
    }
    
    /**
     Actors can adopt diferent behaviours or states, you can "push" a new state into the statesStack by using this method.
     
     - Parameter state: the new state to push
     - Parameter name: The name of the new state, it is used in the logs which is very useful for debugging
     */
    
    final public func become(_ name : String, state : Receive, discardOld : Bool) -> Void  {
        if discardOld { let _ = self.statesStack.pop() }
        self.statesStack.push(element: (name, state))
    }
    
    /**
    Pop the state at the head of the statesStack and go to the previous stored state
    */
    
    final public func unbecome() {
        let _ = self.statesStack.pop()
    }
    
    /**
    Current state
    - Returns: The state at the top of the statesStack
    */
     
    final public func currentState() -> (String,Receive)? {
        return self.statesStack.head()
    }
    
    /**
    Pop states from the statesStack until it finds name
    - Parameter name: the state that you can to pop to.
    */
    
    public func popToState(name : String) -> Void {
        if let (hName, _ ) = self.statesStack.head() {
            if hName != name {
                unbecome()
                popToState(name: name)
            }
        } else {
            #if DEBUG
                print("unable to find state with name \(name)")
            #endif
        }
    }
    
    /**
    pop to root state
    */
     
    public func popToRoot() -> Void {
        while !self.statesStack.isEmpty() {
            unbecome()
        }
    }
    
    /**
    This method handles all the system related messages, if the message is not system related, then it calls the state at the head position of the statesstack, if the stack is empty, then it calls the receive method
    */
     
    final public func systemReceive(_ msg : Unmanaged<Actor.Message>) -> Void {
		let realMsg = msg.takeUnretainedValue()
        switch realMsg {
        case is Harakiri, is PoisonPill:
            self.willStop()
            self.children.forEach({ (_,actor) in
                actor.this ! Harakiri(sender:this)
            })
            self.context.stop(self.this)
            // sender = nil
        default :
            if let (name,state) : (String,Receive) = self.statesStack.head() {
                #if DEBUG
                    print("Sending message to state \(name)")
                #endif
                state(realMsg)
            } else {
                self.receive(realMsg)
            }
            // sender = nil
        }
    }
    
    /**
    This method will be called when there's an incoming message, notice that if you push a state int the statesStack this method will not be called anymore until you pop all the states from the statesStack.
    
    - Parameter msg: the incoming message
    */
    
    public func receive(_ msg : Actor.Message) -> Void {
        switch msg {
            default :
            #if DEBUG
                print("message not handled \(msg.dynamicType)")
            #endif
        }
    }
    
    /**
    This method is used by the ActorSystem to communicate with the actors, do not override.
    */
    
    final public func tell(_ msg : Unmanaged<Actor.Message>) -> Void {
        // mailbox.addOperationWithBlock { () in
        //     self.sender = msg.sender
        //     print("\(self.sender?.path.asString) told \(msg) to \(self.this.path.asString)")
        //     self.systemReceive(msg)
        // }
        underlyingQueue.async { () in
			// let realMsg = msg.takeUnretainedValue()
            // self.sender = realMsg.sender
            #if DEBUG
                print("\(self.sender?.path.asString) told \(msg) to \(self.this.path.asString)")
            #endif
            self.systemReceive(msg)
        }
    }
    
    /**
     Is called when an Actor is started. Actors are automatically started asynchronously when created. Empty default implementation.
    */
     
    public func preStart() -> Void {
        
    }
    
    /**
     Method to allow cleanup
     */
    
    public func willStop() -> Void {
        
    }
    
    /**
    Schedule Once is a timer that executes the code in block after seconds
    */
     
    final public func scheduleOnce(_ seconds : Int, block : (Void) -> Void) {
        //dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(seconds * Double(NSEC_PER_SEC))), self.mailbox.underlyingQueue!, block)
        underlyingQueue.after(when: DispatchTime.now() + DispatchTimeInterval.seconds(seconds),
                                   execute: block)
    }
	/*
		 Schedule Once is a timer that executes the code in block after seconds and can cancle
	*/
	public typealias Task = (cancel : Bool) -> Void
    public func delay(time:TimeInterval, task: ()->() ) ->  Task? {     
        var closure: (()->())? = task
        var result: Task?
        
        func dispatch_later(block:()-> ()) {
            underlyingQueue.after(when: DispatchTime.now() + time,
                                       execute: block)
        }

        let delayedClosure: Task = {
            cancel in
            if let internalClosure = closure {
                if (cancel == false) {                
                    self.underlyingQueue.after(when: DispatchTime.now() + time,
                                               execute: internalClosure)
                }
            }
            closure = nil
            result = nil
        }

        result = delayedClosure

        dispatch_later {
            if let delayedClosure = result {            
                delayedClosure(cancel: false)
            }
        }

        return result
    }

    public func cancel(task:Task?, cancle:Bool) {
        task?(cancel: cancle)
    }
    /**
    Default constructor used by the ActorSystem to create a new actor, you should not call this directly, use  actorOf in the ActorSystem to create a new actor
    */
    
    required public init(context : ActorSystem, ref : ActorRef, args: [Any]! = nil) {
        // mailbox.maxConcurrentOperationCount = 1 //serial queue
        // mailbox.underlyingQueue = dispatch_queue_create(ref.path.asString, nil)
        // underlyingQueue = dispatch_queue_create(ref.path.asString, nil)
		underlyingQueue = context.getQueue()
        // sender = nil
        self.context = context
        self.this = ref
        super.init()
		self.this.actorInstance = self
        self.preStart()
    }
    
    public init(_ context : ActorSystem) {
        // mailbox.maxConcurrentOperationCount = 1 //serial queue
        // mailbox.underlyingQueue = dispatch_queue_create("", nil)
        // underlyingQueue = dispatch_queue_create("", nil)
		underlyingQueue = context.getQueue()
        // sender = nil
        self.context = context
        self.this = ActorRef(context: context, path: ActorPath(path: ""))
        super.init()
		self.this.actorInstance = self
        self.preStart()
    }

    deinit {
        #if DEBUG
            print("killing \(self.this.path.asString)")
        #endif
		self.this.actorInstance = nil
    }

}
