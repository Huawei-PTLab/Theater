# Introduction

This document describes some design decisions we made in writing swift version Theater library. The design and implementation is totally different to the original Theter library from Dario A Lencina-Talarico.


# Basic Actor Classes

We follows AKKA's way to implement the actor with three parts
* Actor: The minimal part of actor, user provided. It may fail. 
* ActorCell: The context of an Actor. Library provided. Never fails.
* ActorRef: A reference to a ActorCell. It can be passed around, and used by others to send message to the ActorCell.

## Actor
Actor only contains user's code logic to handle a message. The main routine is `receive(msg:Message)`, or it can start a FSM and process message in a FSM way.

## ActorCell
It contains all the context information for an actor. When an actor fails, all the context information should be still there. Then the context information can be used to restart the actor.

Context information includes the current location, children (the current actor supervise), parent (the current actor's supervisor). The message queue (so no message will get lost even an actor is fails). The actor's FSM's state stack. Although the stack is in the context, the stack will be cleaned when an actor restarts. 

## ActorRef

Contains the location information, and reference to the ActorCell.

## Life Cycles
### Creation
Actor system (one actor cell) uses `actorOf()` to create an actor.
* Create another cell, and add it into its children
* Create an actorRef to the cell
* Create the actor instance, and set its context(actorCell) and ref (this)


## Connection relationships

Because Swift's RC mechanism, we should carefully design the reference relationships to prevent refernece cycle.

```
Actor -> .context/unowned  -> ActorCell 
      <-  .actor/optional Strong <-
      
Free an actor: set ActorCell.actor = nil or another actor.
Cannot set ActorCell.actor as non-optional because of the initialization order.
Actor.this is a read property of .context.this

ActorCell -> .this/unowned -> ActorRef
           <- .context/optional Weak <- 
           
In summary
ActorCell:
In:  parent ActorCell context's children field, strong
In:  Actor: unowned
In:  ActoreRef: weak. may not contain value

Out: Actor .actor: optional Strong 
Out: ActorRef .this: unowned
Out: Children to ActorCell: Strong

Actor:
In: context's .actor: Strong
Out: ActorCell .context: unowned

ActorRef:
In: No default Strong In. Who uses it who owns it
    ActorCell context .this. : unowned
Out: .context: weak. 
```        

## Creation Sequence

In a context's actorOf, 
1. Create the actorRef with the new name and context's this's path.
2. Update current contex's children. Add entry name -> Children Ref
3. Create a new ActorCell with the ActorRef, 
4. Create an Actor with the input initializor and set the context?
   Note, how to set the context. Maybe it's better to pass it in
5. Update context's actor field. 


# Design Dilemma
## Problem of Putting Children Actor creation in current actor's constructor `init()` or current's actor's fields.

Suppose we want to create an child actor in the current actor. We need the context of the current actor to do that.
```
class Actor { unowned var context:ActorCell! } //has the context in the super class
class MyActor : Actor  {
  let oneActor : ActorRef
  init(...) {
     oneActor = context.actorOf(...)
  }
}
```

The problem here is we cannot initialize context in Swift's class initialization model.
Swift requires child class initialize all its fields before initializing its super class. 

So we have to do `oneActor = context.actorOf(...)` in the prestart(). At that point, the context is set.

We need pass in the context for the current actor, so that the current actor can
use it to create its child actor. The problem here is how to pass in the context.

The current AKKA can look into the thread local map to look for the latest context. In our design, we just use exteral set to do that.


# Support Different Paralel Executor 
We plan to support these exectuors
* Default Dispatcher
  Each ActorCell has a LibDispatch Queue. Mssage queue is also the operation queue
* Share Dispatcher
  All actors share N libDispatch Queue. Random assign at the beginning
* Sequential Dispatcher
  Each actor has its own message queue. A simple sequential executor based on task queue for operation scheduling
* Parallel Dispatcher
  Each actor has its own message queue. A shared libDispatch parallel queue for operation scheduling

