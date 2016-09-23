= Introduction =

This document describes some design decisions we made in writing swift version Theater library. The design and implementation is totally different to the original Theter library. 


= Basic Actor Classes =

We follows AKKA's way to implement an actor with three classes
* Actor: The minimal part of actor, user provided. It may fail. 
* ActorCell: The context of one actor. Runtime provided. Never fails.
* ActorRef: A reference to a ActorCell. It can be passed around, and used by others to send message to the actor.

== Actor ==
Actor only contains user's code logic to handle a message. 

== ActorCell ==
It contains all the context information for an actor. Even an actor fails, and is restarted, all the context information should be still there.

Context information includes the current location, children (the current actor supervise), parent (the current actor's supervisor). The message queue. The state machine's stack. 

== ActorRef ==

Contains the location information, and reference to actor cell.

== Life Cycles ==
=== Creation ===
Actor system (one actor cell) use actorOf to create an actor.
* Create another cell, and add it into its children
* 


== Connection relationships ==


==

Actor -> .context/unowned  -> ActorCell 
      <-  .actor/optional Strong <-
Problem here? actor is freed??
ActorCell -> .this/unowned -> ActorRef
           <- .context/Weak <- 
           
           
Only path: 
ActorCell:
In:  parent context's children field
In:  Actor: unowned
In:  actoreRef: weak. may not contain value

Out: actor: Strong 
Out: this: unowned
Out: Children: Strong

Actor:
In: context's actor: Strong
Out: to ActorCell: unowned

ActorRef:
In: No default Strong In. Who uses it who owns it
    context's this. : unowned
Out: context: weak. 
        

== Creation Sequence ==

In a context's actorOf, 
1. Create the actorRef with the new name and context's this's path.
2. Update current contex's children. Add entry name -> Children Ref
3. Create a new ActorCell with the ActorRef, 
4. Create an Actor with the input initializor and set the context?
   Note, how to set the context. Maybe it's better to pass it in
5. Update context's actor field. 



= Problem of Putting Children Actor creation in init() or ActorFields =

Suppose we want to create an child actor in the current actor. We need the context of the current actor to do that.
```
class Actor { var context:ActorCell } //has the context in the super class
class MyActor : Actor  {
  let oneActor : ActorRef
  init(...) {
     oneActor = context.actorOf(...)
  }
}
```

The problem here is we cannot initialize context in Swift's class initialization model.
Swift requires child class initialize all before initializing its super class. 

So we have to do this in the prestart(). At that point, the context is set.

We need pass in the context for the current actor, so that the current actor can
use it to create its child actor. The problem here is how to pass in the context.

The current actor can look into the thread local map to look for the latest context.










= Support Different Execution Platform =

