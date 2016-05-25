#!/bin/bash
mkdir -p build
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

~/app/swift/usr/bin/swiftc  -Xcc -fblocks -g \
			    -I build \
			    -L build \
			    -lTheater \
			    -Xlinker -rpath -Xlinker $PWD/build\
			    -o build/pingpong\
			    Actors/main.swift\
			    Actors/PingPong.swift

./build/pingpong
