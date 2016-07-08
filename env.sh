#!/bin/bash
# usage:
# 1) build theater
# bash env.sh Theater
# 2) build PingPong
# bash env.sh Theater PingPong
# 3) build GreetingActor
# bash env.sh Theater GreetingActor
# 3) build CloudEdgeUSN
# bash env.sh Theater CloudEdgeUSN

mkdir -p build
Theater() {
	swiftc  -Xcc -fblocks -g -Ounchecked  \
    		-emit-library \
			-emit-module \
			-module-name Theater\
			-emit-module-path=build/Theater.swiftmodule\
			-o build/libTheater.so\
			Classes/Actor.swift\
			Classes/ActorSystem.swift\
			Classes/Message.swift\
			Classes/Stack.swift\
			Classes/NSOperationQueue.swift
}


PingPong() {
	swiftc  -Xcc -fblocks -g \
			-I build \
			-L build \
			-lTheater \
			-Xlinker -rpath -Xlinker $PWD/build\
			-o build/pingpong\
			Actors/PingPong.swift

	./build/pingpong
}
GreetingActor() {
	swiftc  -Xcc -fblocks -g \
			-I build \
			-L build \
			-lTheater \
			-Xlinker -rpath -Xlinker $PWD/build\
			-o build/ConsoleGreetingActor\
			Actors/ConsoleGreetingActor.swift
	./build/ConsoleGreetingActor
}

CloudEdgeUSN(){
	swiftc -Xcc -fblocks -g  -Ounchecked\
		   -I build/ \
		   -L build \
		   -Xlinker -lTheater\
		   -Xlinker --rpath -Xlinker $PWD/build\
		   -o build/CloudEdgeUSN\
		   Actors/CloudEdgeUSN.swift
	./build/CloudEdgeUSN 10
}
while [ -n "$1" ]; do
    printf "====================%s====================\n" "$1"
    $1
    shift
done
