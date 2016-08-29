# Theater: Actor Framework for Swift 

Theater is an open source Actor model framework for Swift, featuring lightweight implementation, user-friendly APIs, and more. 

The design is insipred by [Akka](http://akka.io), and this project is forked from [darioalessandro/Theater](https://github.com/darioalessandro/Theater).

Major changes have been made in our version of Theator, including
* Fixing correctness issues, like data race in the actor path update.
* Performance Improvement, in some test cases, 10x faster
* Important new features, like Actor Selection from Path, Supervision mechanism, etc.
* Architecture and API refactoring to support new features

# Build Theater #

## Install **swift** and **libdispatch**

Install the latest Swift Trunk version, like Aug 26, 2016 from [Swift.org](https://swift.org/download/#snapshots)

The latest snapshot version has shipped with libdispatch. No additional compiling is required.

## Compile Theater

Theater uses standard [swift package manager]("https://github.com/apple/swift-package-manager"):

	swift build -Xswiftc -Ounchecked -Xswiftc -g

The `-Ounchecked` and `-g` options are optional.

# Testing #

Use the following command to build and test

	swift build && swift test

Current test suite includes:

* PingPong
* Greetings
* CloudEdge

# Features #

TODO

# Usage #

Check the examples in `Tests/Theater/` for sample usage.

