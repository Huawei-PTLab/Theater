//
// Copyright (c) 2016 Huawei PT-Lab Open Source project authors.
// Licensed under Apache License v2.0
//
// Error.swift
// The Error definitions for Actors
//


/**
    Errors that could happen in the ActorSystem
*/
enum InternalError: Error {
    case invalidActorPath(pathString: String)
    case noSuchChild(pathString: String)
    case nullActorRef
    case nullActorInstance(actorRef: ActorRef)
}

public enum TheaterError: Error {
    case unexpectedMessage(msg: Actor.Message)
}
