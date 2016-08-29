//
// Copyright (c) 2015 Dario Lencina and Huawei PT-Lab Open Source project authors.
// Licensed under Apache License v2.0
//
// Actor.swift
// The basic Actor definition
//

import Foundation
import Dispatch

precedencegroup ActorMessageSendGroup {
    associativity: left
    higherThan: AssignmentPrecedence
    lowerThan: TernaryPrecedence
}
infix operator ! : ActorMessageSendGroup
//infix operator ! {associativity left precedence 130}

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

public typealias Receive = (Actor.Message) throws -> (Void)

/**
    Actors are the central elements of Theater.

    ## Subclassing notes

    You must subclass Actor to implement your own actor classes such as: BankAccount, Device, Person etc.

    the single most important to override is
     
    ```
    public func receive(msg : Actor.Message) -> Void
    ```
     
    Which will be called when some other actor tries to ! (tell) you something
*/
open class Actor: NSObject {
    
    /**
        Here we save all the actor states
    */
    final public let statesStack : Stack<(String,Receive)> = Stack()
    
    /**
        Each actor has it's own mailbox to process Actor.Messages.
    */
    final internal var underlyingQueue: DispatchQueue! = nil
    
    /**
        Reference to the ActorRef of the current actor
    */
    internal var _ref : ActorRef? = nil

    private var dying = false

    public var this: ActorRef {
        if let ref = self._ref {
            return ref
        } else {
            print("[ERROR] nil _ref, terminating system")
            exit(1)
        }
    }

    public func stop() {
        this ! Harakiri(sender:nil)
    }
    
    public func stop(_ actorRef : ActorRef) -> Void {
        underlyingQueue.async { () -> Void in
            let path = actorRef.path.asString
            self.this.children.removeValue(forKey: path)
            actorRef.actorInstance = nil
        }
    }
    
    /** 
        Generate a random name for the new actor
    */
    public func actorOf(_ initialization: @escaping () -> Actor) -> ActorRef {
        return actorOf(initialization, name: NSUUID().uuidString)
    }

    /**
        Pass in a new actor instance, wrap it with ActorRef and return the
        ActorRef
    */
    public func actorOf(_ initialization: @escaping () -> Actor, name : String) -> ActorRef {
        let actorInstance = initialization()
        //TODO: should we kill or throw an error when user wants to reuse address of actor?
        let completePath = "\(self.this.path.asString)/\(name)"
        let ref = ActorRef(
            path:ActorPath(path:completePath), 
            actorInstance: actorInstance, 
            context: this.context,
            supervisor: self.this,
            initialization: initialization
            )
        actorInstance._ref = ref
        actorInstance.underlyingQueue = this.context.assignQueue()
        underlyingQueue.async { () in 
            self.this.children[completePath] = ref
        }
        return ref
    }

    class func createSupervisorActor(name: String, context: ActorSystem) -> ActorRef {
        let supervisorActor = Actor()
        let ref = ActorRef(
            path: ActorPath(path: "\(name)/user"), 
            actorInstance: supervisorActor,
            context: context
            )
        supervisorActor._ref = ref
        supervisorActor.underlyingQueue = context.assignQueue()
        return ref
    }

    public func selectChildActor(pathString: String) throws -> ActorRef {
        guard pathString.hasPrefix(this.path.asString) else {
            throw InternalError.noSuchChild(pathString: pathString)
        }
        underlyingQueue.sync { () in
            // nothing, wait for enqueued changes to complete
        }
        if pathString == this.path.asString {
            return this
        } else {
            let nextIdx = this.path.asString.characters.split(separator: "/").count
            let nextPath: String = 
                   "\(this.path.asString)/\(pathString.characters.split(separator: "/").map(String.init)[nextIdx])"
            let next: ActorRef? = this.children[nextPath]
            if let nextNode = next {
                return try nextNode.actorInstance!.selectChildActor(pathString: pathString)
            } else {
                throw InternalError.invalidActorPath(pathString: pathString)
            }
        }
    }

    public func selectActor(pathString: String) throws -> ActorRef {
        return try this.context.selectActor(pathString: pathString)
    }

    // TODO
    public func getChildrenActors() -> [String: ActorRef] {
        return this.children
    }
    
    
    /**
        Actors can adopt diferent behaviours or states, you can "push" a new
        state into the statesStack by using this method.
        
        - Parameter state: the new state to push
        - Parameter name: The name of the new state, it is used in the logs
        which is very useful for debugging
    */
    final public func become(_ name : String, state : @escaping Receive) -> Void  {
        become(name, state : state, discardOld : false)
    }
    
    /**
         Actors can adopt diferent behaviours or states, you can "push" a new
         state into the statesStack by using this method.
         
         - Parameter state: the new state to push
         - Parameter name: The name of the new state, it is used in the logs
         which is very useful for debugging
     */
    final public func become(_ name : String, state : @escaping Receive, discardOld: Bool) -> Void { 
        if discardOld {
             _ = self.statesStack.replaceHead(element: (name, state))
        } else {
             self.statesStack.push(element: (name, state))
        }
    }

    /**
        Pop the state at the head of the statesStack and go to the previous
        stored state
    */
    final public func unbecome() { let _ = self.statesStack.pop() }
    
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
    open func popToState(name : String) -> Void {
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
        This method handles all the system related messages, if the message is
        not system related, then it calls the state at the head position of the
        statesstack, if the stack is empty, then it calls the receive method
    */
    final public func systemReceive(_ msg : Unmanaged<Actor.Message>) -> Void {
        let realMsg = msg.takeUnretainedValue() 
        switch realMsg { 
        case is ErrorMessage:
            self.supervisorStrategy(errorMsg: realMsg as! ErrorMessage)
        case is Harakiri, is PoisonPill:
            self.dying = true
            self.willStop() 
            underlyingQueue.async { () in 
                if self.this.children.count == 0 && self.this.supervisor != nil {
                    /**
                        The order of these two calls matters! Upon receiving
                        Terminated msg, supervisor checks the children size, and
                        the checking should only happen after stop() removes the
                        child.
                    */
                    self.this.supervisor!.stop(self.this)
                    self.this.supervisor! ! Terminated(sender: self.this)
                } else {
                    self.this.children.forEach({
                        (_,actorRef) in actorRef ! Harakiri(sender:self.this) 
                    })
                }
            }
        case is Terminated:
            if dying {
                underlyingQueue.async {
                    if self.this.children.count == 0 {
                        if let supervisor = self.this.supervisor {
                            supervisor.stop(self.this)
                            supervisor ! Terminated(sender: self.this)
                        } else {
                            // This is the root of supervision tree
                            print("[INFO] ActorSystem \(self.this.context.name) termianted")
                        }
                    }
                }
            }
        default: 
            if let (name, state) : (String, Receive) = self.statesStack.head() { 
                #if DEBUG 
                print("Sending message to state\(name)") 
                #endif 
                do {
                    try state(realMsg) 
                } catch {
                    if let supervisor = this.supervisor {
                        supervisor ! ErrorMessage(error, sender: this)
                    }
                }
            } else { 
                do {
                    try self.receive(realMsg)
                } catch {                    
                    if let supervisor = this.supervisor {
                        supervisor ! ErrorMessage(error, sender: this)
                    }
                }
            }
        }
    }
    
    /**
        This method will be called when there's an incoming message, notice
        that if you push a state int the statesStack this method will not be
        called anymore until you pop all the states from the statesStack.
    
        - Parameter msg: the incoming message
    */
    open func receive(_ msg : Actor.Message) throws -> Void {
        switch msg {
            default :
            #if DEBUG
                print("message not handled \(type(of:msg))")
            #endif
        }
    }

    /**
        User specifies handling of errors using this method.
        (learned from Akka)
    */
    open func supervisorStrategy(errorMsg: ErrorMessage) -> Void {
        switch(errorMsg) {
        default:
            print("\(self.this) got \(errorMsg.error) from child \(errorMsg.sender!)")
            print("[INFO] restarting \(errorMsg.sender!.path.asString)")
            errorMsg.sender!.restart()
        }
    }
    
    /**
        This method is used by the ActorSystem to communicate with the actors,
        do not override.
    */
    final public func tell(_ msg : Unmanaged<Actor.Message>) -> Void {
        underlyingQueue.async { () in
            // let realMsg = msg.takeUnretainedValue() self.sender =
            // realMsg.sender
            self.systemReceive(msg) 
        } 
    }
    
    /**
         Is called when an Actor is started. Actors are automatically started
         asynchronously when created. Empty default implementation.
    */
    open func preStart() -> Void {
        
    }
    
    /**
         Method to allow cleanup
     */
    open func willStop() -> Void {
        
    }
    
    /**
        Schedule Once is a timer that executes the code in block after seconds
    */
    final public func scheduleOnce(_ seconds: Int, block : @escaping (Void) -> Void) {
        //dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(seconds * Double(NSEC_PER_SEC))), self.mailbox.underlyingQueue!, block)
        underlyingQueue.asyncAfter(deadline: DispatchTime.now() + DispatchTimeInterval.seconds(seconds),
                                   execute: block)
    }

    /*
        Schedule Once is a timer that executes the code in block after seconds
        and can cancle
    */
    public typealias Task = (Bool) -> Void 

    //TODO
    // public func delay(time:TimeInterval, task: ()->() ) ->  Task? {     
        
        // func dispatch_later(block:()-> ()) {
            // underlyingQueue.after(when: DispatchTime.now() + time,
                                       // execute: block)
        // }

        // let delayedClosure: Task = {
            // cancel in
            // if let internalClosure = closure {
                // if (cancel == false) {                
                    // self.underlyingQueue.after(when: DispatchTime.now() + time,
                                               // execute: internalClosure)
                // }
            // }
            // closure = nil
            // result = nil
        // }

        // result = delayedClosure

        // dispatch_later {
            // if let delayedClosure = result {            
                // delayedClosure(cancel: false)
            // }
        // }

        // return result
    // }

    //TODO
    // public func cancel(task:Task?, cancle:Bool) {
    //     task?(cancel: cancle)
    // }

    /**
        Default constructor used by the ActorSystem to create a new actor, you
        should not call this directly, use  actorOf in the ActorSystem to create a
        new actor
    */
    public override init() {
        super.init()
        self.preStart()
    }

    deinit {
        #if DEBUG
            print("[INFO] deinit \(self.this.path.asString)")
        #endif
    }

}
