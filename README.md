# Theater: Actor Framework for Swift 

[![Build Status](https://travis-ci.org/Huawei-PTLab/Theater.svg?branch=master)](https://travis-ci.org/Huawei-PTLab/Theater)
![Swift3](https://img.shields.io/badge/Swift-3.0-orange.svg?style=flat)
![macOS](https://img.shields.io/badge/os-macOS-green.svg?style=flat)
![Linux](https://img.shields.io/badge/os-linux-green.svg?style=flat)
![Apache 2](https://img.shields.io/badge/license-Apache2-blue.svg?style=flat)


Theater is an open source Actor model framework for Swift, featuring lightweight
implementation, user-friendly APIs, and more. The design is insipred by 
[AKKA](http://akka.io), and this project is forked from
[darioalessandro/Theater](https://github.com/darioalessandro/Theater).

Major changes have been made in our version of Theator, including
* **Fixing Correctness Issues**: like data race in the actor path update.
* **Performance Improvement**: in some test cases, 10x faster
* **Better APIs and Internal Architecture**: for performance and new features
* **Important New Features**: like locating Actor from Path, supervision 
  mechanism, etc.

This actor library is based on Swift3.0, and support both Mac and Linux 
platform. Applications with millions of Actors have been tested with the library.

# Usage Example

## Tutorial

Here we use a small PingPong example to show the usage.

First, we create a Swift package

```bash
mkdir PingPong && cd PingPong
swift package init --type executable
```

Modify the *Package.swift* file to add the dependence to Theater

```swift
import PackageDescription

let package = Package(
    name: "PingPong",
    dependencies: [
      .Package(url: "git@github.com:Huawei-PTLab/Theater.git",
	       versions: Version(1,2,2)..<Version(2,0,0)),
    ]
)
```

Now let's modify the *Sources/main.swift* file. 

First we define the PingPong's message `Ball`, which inherits `Actor.Message`.
All actors can only interact with each other with messages. `Actor.Message` has
a field `let sender:ActorRef?`. The receiver of the message can use the `sender`
to send message back. 

```swift
class Ball : Actor.Message {}
```

We then define the simple `Pong` actor, which inhertis `Actor`. The most 
important thing to implement one actor is to override the `receive()` function,
so that the actor can perform actions if it receives messages. Because an actor
may receive different types of messages, a `switch` is commonly used inside
the `receive()` function.

Here, we only print a "pong" text, and then send a new Ball back. Although in 
our sample code, there is a `Thread.sleep()`, it's not a good idea to sleep in
side an actor's `recieve()` function in a typical situation.

```swift
class Pong : Actor {
    override func receive(_ msg: Actor.Message) throws {
        switch(msg) {
        case is Ball:
            print("Pong")
            Thread.sleep(forTimeInterval: 1)
            msg.sender! ! Ball(sender: this)
        default:
            print("wrong type msg")
        }
    }
}
```
In order to create the `Pong` actor, we first need an actor system, and use
the `actorOf` function. This function requires a String name and an actor
constructor with type `(ActorCell)->Actor`.  Because `Actor` class's `init()` is
this type, we just use it directly.

```swift
let system = ActorSystem(name: "PingPong")
let pong:ActorRef = system.actorOf(name:"pong", Pong.init)
``` 

`actorOf` returns an `actorRef` pointing to the real Pong actor. The **Actor**
and **ActorRef** concepts are directly borrowed from AKKA. **ActorRef** is 
exposed to the users while the logic of the actor is hidden inside the **Actor**.

Now we can define our `Ping` class, which contains a field to `Pong`. 

```swift
class Ping : Actor {
    let pong : ActorRef 
    init(context:ActorCell, pong:ActorRef) {
        self.pong = pong
        super.init(context:context)
    }

    override func receive(_ msg: Actor.Message) throws {
        switch(msg) {
        case is Ball:
            print("Ping")
            Thread.sleep(forTimeInterval: 1)
            pong ! Ball(sender: this)
        default:
            print("wrong type msg")
        }
    }
}
```

In order to set the `pong` field, we defined a new constructor. Because the 
new constructor's type is different to `(ActorCell)->Actor`, in order to create
the actor, we can use a closure. 

```switch
let ping = system.actorOf(name:"ping") {
    context in Ping(context:context, pong:pong)
}
```

The reason a closure or a constructor is 
required for `system.actorOf()` is for the fault-tolerance feature. If the real
actor instance is dead for some reason, the actor system can restart it with
the constructor and all the parameters. With the speration of `ActorRef` and 
`Actor`, the external world does not need to know what's happened inside. 

Finally, we send the `ping` a ball to start the pingpong game. Because of the
current Swift's threading model, we have to wait in the main thread otherwise
the application will terminate immediately. We wait 5 seconds in main thread, 
and shut down the actor system by calling `system.shutdown()`, which is a 
non-blocking call. Then we call `system.wait()` until the whole system is 
completely shut down. 

```
ping ! Ball(sender:nil)
Thread.sleep(forTimeInterval: 5)
system.shutdown()
system.wait()
```

Let's put all together

```swift
import Foundation
import Theater

class Ball : Actor.Message {}

class Ping : Actor {
    let pong : ActorRef 
    init(context:ActorCell, pong:ActorRef) {
        self.pong = pong
        super.init(context:context)
    }

    override func receive(_ msg: Actor.Message) throws {
        switch(msg) {
        case is Ball:
            print("Ping")
            Thread.sleep(forTimeInterval: 1)
            pong ! Ball(sender: this)
        default:
            print("wrong type msg")
        }
    }
}

class Pong : Actor {
    override func receive(_ msg: Actor.Message) throws {
        switch(msg) {
        case is Ball:
            print("Pong")
            Thread.sleep(forTimeInterval: 1)
            msg.sender! ! Ball(sender: this)
        default:
            print("wrong type msg")
        }
    }
}

let system = ActorSystem(name: "PingPong")
let pong = system.actorOf(name:"pong", Pong.init)
let ping = system.actorOf(name:"ping") {
    context in Ping(context:context, pong:pong)
}

ping ! Ball(sender:nil)
Thread.sleep(forTimeInterval: 5)
system.shutdown()
system.wait()
```

Compile it and run

```bash
swift build
.build/debug/PingPong
```

Other features and usages can be found under [Docs](Docs) or read the
[Tests/TheaterTests](Tests/TheaterTests).


# Developing Theator 

## Compile Theater

Theater uses standard 
[swift package manager]("https://github.com/apple/swift-package-manager"):

```bash
swift build -Xswiftc -Ounchecked -Xswiftc -g
```

The `-Ounchecked` and `-g` options are optional.

## Testing #

Use the following command to build and test
```bash
swift build && swift test
```

All the current tests can be found in [Tests/TheaterTests](Tests/TheaterTests).

## Design

Design document is under [Docs](Docs).

