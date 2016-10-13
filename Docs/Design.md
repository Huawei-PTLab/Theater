# Introduction

This document describes some design decisions we made in writing swift version
Theater library. The design and implementation is totally different to the
original Theter library from Dario A Lencina-Talarico.


# Basic Actor Classes

We follows AKKA's way to implement the actor with three parts
* Actor: The minimal part of actor, user provided. It may fail. 
* ActorCell: The context of an Actor. Library provided. Never fails.
* ActorRef: A reference to a ActorCell. It can be passed around, and used by others to send message to the ActorCell.

Besides them, there is a speical class ActorSystem.

## Actor
Actor only contains user's code logic to handle a message. The main routine is
`receive(msg:Message)`, or it can start a FSM (Finite State machine) and process 
message in a state transition way. 

## ActorCell
It contains all the context information for an actor. Or you can combine an
instance of an dfdf When an actor fails, all the context information should be
still there. Then the context information can be used to restart the actor.
The actorCell will only be cleaned when the stop request is received.

Context information includes the current location, children (the current actor
supervises), parent (the current actor's supervisor). The message queue (so no 
message will get lost even an actor instance fails). Note, the actor's FSM's
state is managed in the actor instance. So when an actor fails, the states will
get lost.

## ActorRef

It is a reference to an actorCell. Other actors can use it to send message to
the target actor. It contains the location information, and the reference to the 
ActorCell.

## ActorSystem

ActorSystem is a special container to contain all the actors. ActorSystem could
extend ActorCell since they both have many similarities. However, due to some
Swift implementation issue, it's hard to extend it. For example, these code 
does not compile in Swift3.

    public class ActorCell  { 
      unowned let system : ActorSystem

      public init(system:ActorSystem) {
        self.system = system
      }
    } 

    public class ActorSystem : ActorCell  {
      var name:String

      public init() {
        i = "dfdf"
        super.init(system:self)
      }
    }

## Life Cycles

### Creation

Actor system (one actor cell) uses `actorOf()` to create an actor.
* Create another cell, and add it into its children
* Create an actorRef to the cell
* Create the actor instance, and set its context(actorCell) and ref (this)


## Connection relationships

Because Swift's RC mechanism, we should carefully design the reference 
relationships to prevent reference cycle.

The ownership relationship.

* Without any external references.
  * root/ActorCell's children owns Child's actorRef
  * Child actorRef owns the actor
  * If the the actorRef is shared to someone. 



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
In:  Actor: unowned
In:  ActoreRef: weak. may not contain value 

Out: var actor:Actor? ///Set later, and could be changed. The own link
Out: unowned let this:ActorRef ///Must be set,, and prevent cycle
Out: children:[String:ActorRef] ///Owener of child Strong map
Out: unowned let supervisor:ActorCell?  ///

Actor:
In: context's .actor: Strong

Out: unowned let context:ActorRef ///Must set, and prevent cycle
Out: unowned let this:ActorRef  ///Must be set, and prevent cycle

ActorRef:
In: No default Strong In. Who uses it who owns it

    ActorCell context .this. : owned. Prevent clean


Out: .context: weak optional. An actorcell may dead  
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

