//
// Copyright (c) 2016 Huawei PT-Lab Open Source project authors.
// Licensed under Apache License v2.0
//
// Supervision.swift
// The Actor System supervision mechanism implementation
//

import Dispatch
/**
    Extend Actor class to add some methods related to supervision
*/
extension Actor {
    /**
        Create a new actor instance and replace the old one.
    */
    final public func restart() {
        self.this.restart()
    }

    /**
        Shutdown the whole ActorSystem, use when failure is too severe.
    */
    final public func escalate() {
        self.this.escalte()
    }
}

extension ActorRef {

    internal func restart() {
        if let actor = self.actorInstance {
            let oldQueue = actor.underlyingQueue!
            oldQueue.async {
                print("debug \(self) is restarting")
                self.actorInstance = self.initialization()
                self.actorInstance!._ref = self
                self.actorInstance!.underlyingQueue = oldQueue
            }
        } else {
            print("[ERROR] Fail to restart \(self)")
            context.stop()
        }    
    }

    internal func escalte() {
        print("[WARNING] Escalating...")
        self.context.stop()
    }
        
}
