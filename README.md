# Theater: Actor Framework for Swift 

Theater is an open source Actor model framework for Swift, featuring lightweight implementation, user-friendly APIs, and more. 

The design is insipred by [Akka]("http://akka.io"), and this project is forked from [darioalessandro/Theater]("https://github.com/darioalessandro/Theater").

Major changes have been made in our version of Theator, including
* Fixing correctness issues, like data race in the actor path update.
* Performance Improvement, in some test cases, 10x faster
* Important new features, like Actor Selection from Path, Supervision mechanism, etc.
* Architecture and API refactoring to support new features

# Build Theater #

Current implementation targets `Ubuntu 15.10`.

## Install **swift** and **libdispatch**

Install preview verison 5 of [Swift 3.0]("https://swift.org/download/#previews")

Compile and install **libdispatch** Note, for Ubuntu 14.04, Clang-3.8 is required to compile libdispatch.

	git clone --recursive -b swift-3.0-preview-5-branch https://github.com/apple/swift-corelibs-libdispatch.git
	cd swift-corelibs-libdispatch
	sh ./autogen.sh
	./configure --with-swift-toolchain=<path-to-swift>/usr --prefix=<path-to-swift>/usr
	make && make install

After installation, you should be able to see a `dispatch` folder under `<path-to-swift>/usr/lib/`. 

## Compile Theater

Theater uses standard [swift package manager]("https://github.com/apple/swift-package-manager"):

	swift build -Xswiftc -Ounchecked -Xswiftc -g -Xcc -fblocks

The `-Ounchecked` and `-g` options are optional.

# Testing #

Use the following command to build and test

	swift build -Xcc -fblocks && swift test

Current test suite includes:

* PingPong
* Greetings
* CloudEdge

# Features #

TODO

# Usage #

Check the examples in `Tests/Theater/` for sample usage.

