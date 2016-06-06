#!/bin/bash
# usage:
# 1) build theater
# bash build-actor-example.sh Theater
# 2) build PingPong
# bash build-actor-example.sh Theater PingPong
# 3) build ConsoleGreetingActor
# bash build-actor-example.sh Theater ConsoleGreetingActor

mkdir -p build
Theater() {
	~/app/swift/usr/bin/swiftc  -Xcc -fblocks -g \
    							-emit-library \
								-emit-module \
								-module-name Theater\
								-emit-module-path=build/Theater.swiftmodule\
								-o build/libTheater.so\
								Classes/Actor.swift\
								Classes/ActorSystem.swift\
								Classes/Message.swift\
								Classes/Stack.swift
}


PingPong() {
	~/app/swift/usr/bin/swiftc  -Xcc -fblocks -g \
								-I build \
								-L build \
								-lTheater \
								-Xlinker -rpath -Xlinker $PWD/build\
								-o build/pingpong\
								Actors/PingPong.swift

	./build/pingpong
}
ConsoleGreetingActor() {
	~/app/swift/usr/bin/swiftc  -Xcc -fblocks -g \
								-I build \
								-L build \
								-lTheater \
								-Xlinker -rpath -Xlinker $PWD/build\
								-o build/ConsoleGreetingActor\
								Actors/ConsoleGreetingActor.swift
	./build/ConsoleGreetingActor
}

while [ -n "$1" ]; do
    printf "====================%s====================\n" "$1"
    $1
    shift
done
