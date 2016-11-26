# Introduction

This document describes the design of the actor library including some design 
decisions we made.The design and implementation is totally different to the
original Theter library from Dario A Lencina-Talarico.


# Actor System Organization
## Basic Actor Classes

We follow AKKA's way to implement the actor with four parts
* `Actor`: The minimal part of actor, user provided. It may fail. 
* `ActorCell`: The context of an Actor, library provided. Never fails. The
   combination of one `ActorCell` instance and one `Actor` is the real actor a
   user faces.
* `ActorRef`: A reference to an actor (ActorCell). It can be passed around, and 
  used by others actors to send messages to it.
* `ActorSystem`: It is a container to hold actors and actor references.

### Actor
Actor only contains user's code logic to process a message. The main routine is
`receive(msg:Message)`, or it can start a FSM (Finite State machine) and process 
message in a state transition way. 

### ActorCell
It contains all the context information for an actor instance. In case the actor
instance fails, all the context information is still in the actorCell. Then the
context information can be used to restart the actor.
The actorCell will only be cleaned when the stop request is received.

Context information includes the current location, children (the current actor
supervises), parent (the current actor's supervisor). The message queue (so no 
message will get lost even an actor instance fails). Note, the actor's FSM's
state is managed in the actor instance. So when an actor fails, the states will
get lost.

### ActorRef

It is a reference to an actorCell. Other actors can use it to send message to
the target actor. It contains the actor path (like a url) and the reference to
its actorCell.


### ActorSystem

ActorSystem is a special container to contain all the actors. ActorSystem could
extend ActorCell since they both have many similarities. However, due to some
Swift implementation issues, it's hard to extend it. For example, these code 
does not compile in Swift3.

```swift
public class ActorCell  { 
  unowned let system : ActorSystem

  public init(system:ActorSystem) {
    self.system = system
  }
} 

public class ActorSystem : ActorCell  {
  var name:String

  public init() {
    name = "actorSystemName"
    super.init(system:self)
  }
}
```
In the current implementation, actorSystem is a separate class which contains a
user root actor (actorCell and actor instance). Many of the operations to the
actor system will be forwarded to the user actor.

## Class Connections

Because Swift's reference counting mechanism, we should carefully design the 
reference relationships to prevent reference cycles.

The only ownership relationship: if there is no external references, the owner 
of each class
* root ActorCell (user cell in Actorsystem)'s `children` owns its child's 
  `actorRef`
* The child's actorRef owns its actorCell.
* The actorCell owns its actor instance.

Case 1: if the actor system has not be referenced by any variable, the 
whole actor system could be cleaned.

Case 2: if the actorRef is stored to a variable. And if its parent removes
the actor (removing the actorRef from the parent's children, and disconnect the
actorRef to actorCell's link). The actorCell and actor instance will be cleaned
but the actorRef itself are still there, referenced by that variable.

Case 3: free an actor instance. Set `ActorCell.actor = nil` or another actor. 
And the previous actor instance should be cleaned.

In summary, the definition: 

**ActorCell**
* In:  Actor.context: unowned
* In: the owner `ActoreRef.actorCell`, optional. nil during initialization or 
 dead.
* Out: `var actor:Actor?` Set later, and could be changed. The owner link
* Out: `unowned let this:ActorRef` Must be set, and prevent cycle
* Out: `children:[String:ActorRef]` The owner link, to the children ref 
* Out: `unowned let supervisor:ActorCell?` May not have supervisor (root), and 
  not the onwer

We cannnot define `ActorCell.actor` as non-optional var because of the 
initialization order. We have to first create the actorCell with out the actor
and then set it later. 

**Actor**
* In: the owner `ActorCell.actor`.
* Out: `unowned let context:ActorRef`, set during construction. The unowned is 
  used to prevent cycle
* Out: `unowned let this:ActorRef`  is a read property of .context.this.

**ActorRef**
* In: No default strong In. The actorCell owns the actorRef has the strong link
  in the actorCell's children.
* In: ActorCell  `.this`, unowned, prevent cycle.
* Out: `var actorCell: ActorCell?` The owner link. Optional. nil during 
  initialization or dead.  


## Life Cycles

### Actor Creation


* Create a new actor ref with the right path, and add it into its children
* Create a new actorCell witht the actor ref and set actor ref's actor cell.
* Create the actor instance, and set its context(actorCell) and ref (this). Then
  call its `preStart()`



## Creation Sequence

An actor system or an actor cell uses `actorOf()` to create a new actor.
1. Create the actorRef with the new name and context's this's path.
2. Update current context's children. Add entry name -> Children Ref
3. Create a new ActorCell with the ActorRef, 
4. Create an Actor with the input initializor and set the context by passing the
   new actorCell in.
5. Update the new actorCell context's actor field. 

# Actor System Exeuction

## Simple Message model

## ShareQueeu Dispatcher

## Support Different Paralel Executor 
We plan to support these exectuors
* Default Dispatcher
  Each ActorCell has a LibDispatch Queue. Mssage queue is also the operation
  queue
* Share Dispatcher
  All actors share N libDispatch Queue. Random assign at the beginning
* Sequential Dispatcher
  Each actor has its own message queue. A simple sequential executor based on 
  task queue for operation scheduling
* Parallel Dispatcher
  Each actor has its own message queue. A shared libDispatch parallel queue for
  operation scheduling

# Design Decisions

## Must pass-in context in an actor's constructor

We want to support two features: 1) new Actor class can define its own constructor
to pass-in construction parameters; 2) create sub actors in an actor class's
construction phase.

However, the feature requirement 2 requires the `context` field to be set. E.g.
Suppose we want to create an child actor in the current actor. We need the 
`context` of the current actor to do that.

```
class Actor { unowned var context:ActorCell! } //has the context in the super class
class MyActor : Actor  {
  let oneActor : ActorRef
  init(...) {
     oneActor = context.actorOf(...)
  }
}
```

The problem here is we cannot initialize context in Swift's class initialization
model. Swift requires child class initialize all its fields before initializing 
its super class. 

So we have to pass the context field in `MyActor`'s `init()` constructor so that
the current actor can use it to create its child actor. However, we still cannot
create field actor like `let oneActor : ActorRef = context.actorOf(...)`

Java's initialization model is different, and the current AKKA can look into the
thread local stack to look for the latest context to set the context field in 
the super class (actor). In Swift, we cannot do that.

## Each actor has a lock inside

There is a lock (NSLock) in `ActorCell` class, which means every actor has a 
lock. The lock is to protect the shared resource of each actor.

The current shared data in each actor is `children`
* The current actor will update it during `actorOf()`, which is called by 
  by another actor/task
* The current actor's receive() will access the children in actions like 
  `Terminated` to remove one child from the children array
* Someone else may call `actorFor()` to look for one actor which requires go
  through the children for the request.

In swift, we can use a sequential queue to protect the access to the shared 
resource. We can use each actor's execution queue as the sequential queue to 
control the access. If each actor uses its own dispatch queue, it has no problem.
However, our library also supports shareQueue model, which means several actors
may use the same dispatchqueu. As a result, if one actor sends a message to
another queue, and the later queue wants to update the `children`, it will
cause the deadlock pattern `q.async { ...; q.sync{} }`

So we have to use a separated lock to protect the shared `children`

And later, in the group dispatcher model, we will use the same lock to protect 
the shared message mailbox, which will be accessed by all the senders and the 
actor's executor.
