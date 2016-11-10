//
// Copyright (c) 2015 Dario Lencina and Huawei PT-Lab Open Source project authors.
// Licensed under Apache License v2.0
//
// Message.swift
// The Message base class definition
//

import Foundation

extension Actor {

    /// Actors can only interact with Actor.Message. Message has a sender field,
    /// which the receiver can use to reply
    /// Message has two categories, SystemMessage and normal Message
    open class Message : CustomStringConvertible {

        /// The ActorRef to the actor that sent this message
        public let sender: ActorRef!

        public init(sender : ActorRef!) {
            self.sender = sender
        }
       
        open var description: String {
             return "Actor.Message: \(Unmanaged.passUnretained(self).toOpaque())>" 
        }
    }

    public class SystemMessage : Message {}

    /// PoisonPill is the default message to kill an actor.
    public final class PoisonPill : SystemMessage {}

    /// Terminated message is used for a child actor notifying its parent that
    /// its termination process is done.
    public final class Terminated: SystemMessage {}

    /// Convenient Message subclass which has an operationId that can be used to 
    /// track a transaction or some sort of message that needs to be tracked
    public class MessageWithOperationId : SystemMessage {

        /// The operationId used to track the Operation
        public let operationId : NSUUID
        
        public init(sender: Optional<ActorRef>, operationId : NSUUID) {
            self.operationId = operationId
            super.init(sender : sender)
        }
    }

    /// Wrapper for sending Errors as messages. It is used for error handling
    public class ErrorMessage: SystemMessage {
        let error: Error
        init(_ e: Error, sender: ActorRef) {
            error = e
            super.init(sender: sender)
        }
    }

    /// DeadLetter is an Actor System generated message that is sent to the
    /// sender of the original message when it tries to send a message to an 
    /// ActorRef that has no bound actor, or the destnation actor is
    /// dead.
    public class DeadLetter : SystemMessage {
        
        public let message : Message
        
        public init(message : Actor.Message, sender: Optional<ActorRef>) {
            self.message = message
            super.init(sender: sender)
        }
    }

    /// AskMessage is a speical message that contains a real message and an
    /// action that is used to form a reply message
    public class AskMessage: SystemMessage {
        let msg:Actor.Message
        /// After the message is processed, the sender of the message will 
        /// perform the action with the result
        let answerAction:(Any?)->Void
        public init(_ msg:Actor.Message, answerAction:@escaping (Any?)->Void) {
            self.msg = msg
            self.answerAction = answerAction
            super.init(sender: msg.sender)
        }
    }


    /// AskReplyMessage is a speical message to reply
    public class AnswerMessage: SystemMessage {
        let answer : Any?
        let answerAction:(Any?)->Void
        public init(sender : ActorRef, answer:Any?,
                    answerAction:@escaping (Any?)->Void) {
            self.answer = answer
            self.answerAction = answerAction
            super.init(sender:sender)
        }
    }

    /// ActorSelect is a speical system message to ask the System or an actor
    /// for a ActorRef with the requested name.
    /// ActorSelect is handled asynchnously.
    /// The reply is wrapped as AnswerMessage, no special
    public class ActorSelect : SystemMessage {
        public let path : String ///Absolute path
        public let answerAction:(ActorRef?)->Void

        ///ActorSelect message must has the sender
        public init(path:String, sender:ActorRef,
                    _ answerAction:@escaping (ActorRef?)->Void) {
            self.path = path
            self.answerAction = answerAction
            super.init(sender: sender)
        }
    }


}
