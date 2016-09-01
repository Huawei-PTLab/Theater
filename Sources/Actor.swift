//
//  Actor.swift
//  Actors
//
//  Created by Dario Lencina on 9/26/15.
//  Copyright © 2015 dario. All rights reserved.
//

import Foundation

public typealias Receive = (Actor.Message) -> (Void)


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
open class Actor {
    
    /**
		Here we save all the actor states
    */
    final public let statesStack : Stack<(String,Receive)> = Stack()
   
    /// Mailbox
    final internal let mailbox = FastQueue<Actor.Message>(initSize:10)
    /// State, whether or not in task queue
    final internal var inTaskQueue : Bool = false
    /// The real executor to run the process function
    final internal var executor: Executor! = nil

    /// Function to process part of the messages
    final internal func processMessage() {
        while let msg = mailbox.dequeue() {
            systemReceive(msg)
        }
        //TODO: if not finish all message, put processMessage back to putAndRun again

        //finished 
        inTaskQueue = false
    }
    
    /**
		Reference to the ActorRef of the current actor
    */
    private var _ref : ActorRef? = nil

	public var this: ActorRef {
		if let ref = self._ref {
			return ref
		} else {
			print("ERROR: nil _ref, terminating system")
			exit(1)
		}
	}

    public func stop() {
        this ! Harakiri(sender:nil)
    }
    
    public func stop(_ actorRef : ActorRef) -> Void {
        // Dispatch: Should be executed in protected
        let path = actorRef.path.asString
        self.this.children.removeValue(forKey: path)
        this.context.allActors.removeValue(forKey: path)
        actorRef.actorInstance = nil
    }
    
	/** 
		Generate a random name for the new actor
	*/
    public func actorOf(_ actorInstance : Actor) -> ActorRef {
        return actorOf(actorInstance, name: NSUUID.init().uuidString)
    }

	/**
		Pass in a new actor instance, wrap it with ActorRef and return the
		ActorRef
	*/
    public func actorOf(_ actorInstance : Actor, name : String) -> ActorRef {
        //TODO: should we kill or throw an error when user wants to reuse address of actor?
        let completePath = "\(self.this.path.asString)/\(name)"
        //print("\(completePath)========")
        let ref = ActorRef(
			path:ActorPath(path:completePath), 
			actorInstance: actorInstance, 
			context: this.context,
			supervisor: self.this
			)
		actorInstance._ref = ref
		actorInstance.executor = this.context.executor
		// Dispatch: Should be executed in protected
		self.this.children[completePath] = ref
        this.context.allActors[completePath] = ref
		
        return ref
    }

	internal class func createSupervisorActor(name: String, context: ActorSystem) -> ActorRef {
		let supervisorActor = Actor()
		let ref = ActorRef(
			path: ActorPath(path: "\(name)/user"), 
			actorInstance: supervisorActor,
			context: context
			)
		supervisorActor._ref = ref
		supervisorActor.executor = context.executor
		return ref
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
              let _ = self.statesStack.replaceHead(element: (name, state))
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
    open func popToRoot() -> Void {
        while !self.statesStack.isEmpty() {
            unbecome()
        }
    }
    
	/**
		This method handles all the system related messages, if the message is
		not system related, then it calls the state at the head position of the
		statesstack, if the stack is empty, then it calls the receive method
    */
	final public func systemReceive(_ realMsg : Actor.Message) -> Void {
		switch realMsg { 
		case is Harakiri, is PoisonPill:
			self.willStop()

            // Dispatch: should be executed in protected
            self.this.children.forEach({ (_,actorRef) in
                actorRef ! Harakiri(sender:this)
            })

            if self.this.supervisor != nil {
                self.this.supervisor!.stop(self.this);
            } else {
                print("ActorSystem \(self.this.context.name) termianted")
            }
		default: 
			if let (name, state) : (String, Receive) = self.statesStack.head() { 
				#if DEBUG 
				print("Sending message to state\(name)") 
				#endif 
				state(realMsg) 
			} else { 
				self.receive(realMsg) 
			}
		}
	}
    
	/**
		This method will be called when there's an incoming message, notice
		that if you push a state int the statesStack this method will not be
		called anymore until you pop all the states from the statesStack.
    
		- Parameter msg: the incoming message
    */
    open func receive(_ msg : Actor.Message) -> Void {
        switch msg {
            default :
            #if DEBUG
                print("message not handled \(type(of: msg))")
            #endif
        }
    }
    
	/**
		This method is used by the ActorSystem to communicate with the actors,
		do not override.
    */
	final public func tell(_ msg : Actor.Message) -> Void {
        mailbox.enqueue(item:msg)
        if !inTaskQueue {
            inTaskQueue = true
            executor.putAndRun(task:processMessage)
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
    public func willStop() -> Void {
        
    }

    /** 
        Method to calculate how much time has elapsed since "begin"
     */
    static public func latencyFrom(_ begin : timeval) -> Double {
        var now = timeval(tv_sec: 0, tv_usec: 0)
        gettimeofday(&now, nil)
        return difftime(now.tv_sec, begin.tv_sec)*1000000 + Double(now.tv_usec - begin.tv_usec);
    }

	/**
		Default constructor used by the ActorSystem to create a new actor, you
		should not call this directly, use  actorOf in the ActorSystem to create a
		new actor
    */
	public init() {
		self.preStart()
	}

    deinit {
        #if DEBUG
            print("deinit \(self.this)")
        #endif
    }

}
