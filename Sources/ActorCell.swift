//
// Copyright (c) 2016 Huawei PT-Lab Open Source project authors.
// Licensed under Apache License v2.0
//
// ActorCell.swift
// Created by Haichuan Wang on 9/29/16.
//
//

import Foundation


///
///
public class ActorCell : CustomStringConvertible {

    /// The current actor's parent. Actor system's parent is nil
    weak var parent : ActorRef? /// `Only actor system's parent is nil
    /// A quick path to access the current ActorSystem
    unowned let system : ActorSystem
    /// To the ActorRef of this actor. Unowned due to not want to cause cycle
    unowned let this: ActorRef
    /// Points to the current actor instance. ActorCell is the owner
    /// It must has a value during the whole life cycle. So use Actor!
    var actor: Actor!
    /// Used to restart the actor instrance
    var actorConstructor: (ActorCell)->Actor
    /// The current actor's children. Key: fullPath; Value: child ActorRef
    /// Note only this actor cell can access (read/write) it. No lock required
    var children = [String:ActorRef]() //Hashtable<String , ActorRef>()

    /// The following fields are used to run the actor
    /// The mailbox and the exectuor
    let underlyingQueue:DispatchQueue
    /// Flag to indicate the actor has started the termination process
    private var dying = false
    /// askResult is used to handle AskMessage. The asked Actor should store a
    /// result here, and the systemReceive will wrap it as an AnswerMessage
    /// If the result is not set (nil), a nil response still be sent back
    private var askResult:Any? = false

    public var description: String {
        return "ActorCell[\(this.path.asString)]"
    }

    /// A lock to protect the usage
    let lock = NSLock() //A lock to protect children update
    func sync<T>(_ closure: () -> T) -> T {
        self.lock.lock()
        defer { self.lock.unlock() }
        return closure()
    }

    /// Called by context.actorOf to create a cell with an actor
    public init(system:ActorSystem,
                parent:ActorRef?,
                actorConstructor: @escaping (ActorCell)->Actor,
                actorRef:ActorRef
                ) {
        self.parent = parent
        self.actorConstructor = actorConstructor
        self.this = actorRef
        self.system = system
        self.underlyingQueue = system.assignQueue()
    }

    /// Create a random name actor in the current context
    public func actorOf(_ actorConstructor: @escaping (ActorCell)->Actor)
                  -> ActorRef {
        return actorOf(actorConstructor, name: NSUUID().uuidString)
    }

    /// Create a new child actor in this context
    public func actorOf(_ actorConstructor: @escaping (ActorCell)->Actor,
                        name: String) -> ActorRef {
        // The steps to create an actor: 1. ActorRef; 2. ActorCell; 3. Actor

        // 1.The actorRef requires a complete path
        let completePath = this.path.asString + "/" + name
        let childRef = ActorRef(path: ActorPath(path:completePath))
        sync {
            children[name] = childRef // Add it to current actorCell's children
        }

        // 2.
        let childContext = ActorCell(system:self.system,
                                     parent:self.this,
                                     actorConstructor: actorConstructor,
                                     actorRef:childRef
                                     )
        childRef.actorCell = childContext

        // 3. ChildActor
        let childActor = actorConstructor(childContext)
        childContext.actor = childActor
        childActor.preStart() //Now the actor is ready to use

        return childRef
    }

    /// Used to stop this system by sending the actor a PoisonPill
    public func stop() {
        this ! Actor.PoisonPill(sender:nil)
    }


    private func receiveActorSelect(msg: Actor.ActorSelect) {
        let qPath = msg.path
        let path = this.path.asString
        var retRef:ActorRef? = nil
        if path == qPath { //Found this one
            retRef = this
        } else if qPath.hasPrefix(path+"/") { // possible in children
            //get diff string
            let rPath = qPath.substring(from: (path+"/").endIndex)
            //split it
            let rPathSecs : [String] = rPath.components(separatedBy: "/")
            if rPathSecs.count > 0 {
                let childPath = path + "/" + rPathSecs[0]
                if let childRef = children[childPath] {
                    if rPathSecs.count == 1 {
                        retRef = childRef
                    } else {
                        //ask childRef continue query
                        childRef ! msg
                        return
                    }
                }
            }
        }

        let reply = Actor.AnswerMessage(sender:this,
                            answer:retRef,
                            answerAction:(msg.answerAction as! (Any?)->Void))
        msg.sender! ! reply

    }

    /// selectActor will take a path string, like "\user\ping" to look for a
    /// real actorRef. The looking is an asynchronous operation, and when the
    /// result is returned, the input action (ActorRef?)->Void will be called
    /// in the current actor context.
    /// - parameter pathString: the string of the actor path, absolute
    /// - parameter action: The call back action after the result is sent back
    public func selectActor(path: String,
                            _ action:@escaping (ActorRef?)->Void) {
        system.selectActor(pathString: path, by: this, action)
    }

    // FIXME: a better way, do a thread safe copy and returns the copy
    public func getChildrenActors() -> [ActorRef] {
        var childrenRefs:[ActorRef] = []
        self.sync {
            children.forEach { (_, v) in childrenRefs.append(v)}
        }
        return childrenRefs
    }

    /**
     This method is used by the ActorSystem to communicate with the actors,
     do not override.
     */
    final public func tell(_ msg : Actor.Message) -> Void {
        underlyingQueue.async {
            self.systemReceive(msg)
        }
    }


    /**
     This method handles all the system related messages, if the message is
     not system related, then it calls the state at the head position of the
     statesstack, if the stack is empty, then it calls the receive method
     */
    final public func systemReceive(_ message : Actor.Message) -> Void {

        switch message {
        case let errorMsg as Actor.ErrorMessage:
            /// Even actor is dying, still need to handle error message.
            actor!.supervisorStrategy(errorMsg: errorMsg)
        case is Actor.PoisonPill:
            guard (self.dying == false) else {
                print("[WARNING]:\(self) receives double poison pills.")
                return
            }
            self.dying = true
            actor!.willStop() /// At this point,  actor is still valid
            sync {
                if self.children.count == 0 && self.parent != nil {
                    // sender must not be null because the parent needs this
                    // to remove current actor from children dictionary
                    self.parent! ! Actor.Terminated(sender: self.this)
                } else {
                    self.children.forEach {
                        (_,actorRef) in actorRef ! Actor.PoisonPill(sender:self.this)
                    }
                }
            }
        case let t as Actor.Terminated: //Child notifies this actor that it is stopped
            // Remove child actor from the children dictionary.
            // If current actor is also waiting to die, check the size of children
            // and die right away if all children are already dead.
            let path = t.sender!.path.asString
            self.sync {
                //Remove two links
                //Need double check thek path's value is the same as the sender
                //It's possible the key is bound to another path
                self.children.removeValue(forKey: path)
                t.sender!.actorCell = nil

                if dying {
                    if self.children.count == 0 {
                        if let parent = self.parent { //Not actorSystem
                            parent ! Actor.Terminated(sender: self.this)
                        } else {
                            // This is the root of supervision tree
                            print("[INFO] \(self) termianted")
                        }
                    }
                }
            }
        case let askMsg as Actor.AskMessage:
            //Must wrap the original message and call and wrap the result
            askResult = nil
            systemReceive(askMsg.msg)
            //construct the reply
            askMsg.sender! ! Actor.AnswerMessage(sender:this,
                                                answer:self.askResult,
                                           answerAction:askMsg.answerAction)
        case let answerMsg as Actor.AnswerMessage:
            // just perform the action
            answerMsg.answerAction(answerMsg.answer)
        case let actorSelectMsg as Actor.ActorSelect:
            receiveActorSelect(msg:actorSelectMsg)
        default:
            guard (self.dying == false) else {
                print("[WARNING]:\(self) is dying. Drop non system messages")
                return
            }
            if let (name, state) : (String, Receive) = actor!.statesStack.head() {
                #if DEBUG
                    print("Sending message to state\(name)")
                #endif
                do {
                    try state(message)
                } catch {
                    if let parent = self.parent {
                        parent ! Actor.ErrorMessage(error, sender: this)
                    }
                }
            } else {
                do {
                    try actor!.receive(message)
                } catch {
                    if let parent = self.parent {
                        parent ! Actor.ErrorMessage(error, sender: this)
                    }
                }
            }
        }
    }

    /**
     Schedule Once is a timer that executes the code in block after seconds
     */
    final public func scheduleOnce(_ seconds: Int, block : @escaping (Void) -> Void) {
        //dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(seconds * Double(NSEC_PER_SEC))), self.mailbox.underlyingQueue!, block)
        underlyingQueue.asyncAfter(deadline: DispatchTime.now() + DispatchTimeInterval.seconds(seconds),
                                   execute: block)
    }


}

