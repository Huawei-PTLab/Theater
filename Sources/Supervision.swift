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
extension ActorCell {
    /**
        Create a new actor instance and replace the old one.
    */
    final public func restart() {

    }

    /**
        Shutdown the whole ActorSystem, use when failure is too severe.
    */
    final public func escalate() {

    }
}

extension ActorRef {

    internal func restart() {

    }

    internal func escalte() {

    }
        
}
