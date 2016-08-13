import XCTest
import Glibc
import Foundation
@testable import Theater

class SelectActorTests: XCTestCase {

	static var allTests: [(String, (SelectActorTests) -> () throws -> Void)] {
		return [
			("testFlat", testFlat),
			("testNested", testNested),
			("testFlatAndNested", testFlatAndNested),
			("testSelectActorInActor", testSelectActorInActor),
		]
	}

	func testFlat() {
		let system = ActorSystem(name: "system")
		let _ = system.actorOf(Ping(), name: "Ping")
		let _ = system.actorOf(Pong(), name: "Pong")

		let ping = try! system.selectActor(pathString: "system/user/Ping")
		let pong = try! system.selectActor(pathString: "system/user/Pong")
		XCTAssertNotNil(ping)
		XCTAssertNotNil(pong)
		pong ! Ball(sender: ping)
		sleep(5)
		system.stop()
		sleep(2)
	}

	func testNested() {
		let system = ActorSystem(name: "system")
		let foo = system.actorOf(PingParent(), name: "Foo")
		let bar = system.actorOf(PongParent(), name: "Bar")
		foo ! Create(sender: nil)
		bar ! Create(sender: nil)

		let ping = try! system.selectActor(pathString: "system/user/Foo/Ping")
		let pong = try! system.selectActor(pathString: "system/user/Bar/Pong")
		XCTAssertNotNil(ping)
		XCTAssertNotNil(pong)
		pong ! Ball(sender: ping)
		sleep(5)
		system.stop()
		sleep(2)
	}

	func testFlatAndNested() {
		let system = ActorSystem(name: "system")
		let foo = system.actorOf(PingParent(), name: "Foo")
		foo ! Create(sender: nil)
		let _ = system.actorOf(Pong(), name: "Pong")

		let ping = try! system.selectActor(pathString: "system/user/Foo/Ping")
		let pong = try! system.selectActor(pathString: "system/user/Pong")
		XCTAssertNotNil(ping)
		XCTAssertNotNil(pong)
		pong ! Ball(sender: ping)
		sleep(5)
		system.stop()
		sleep(2)
	}

	func testSelectActorInActor() {
		let system = ActorSystem(name: "system")
		let _ = system.actorOf(HeadlessPing(), name: "Ping")
		let _ = system.actorOf(HeadlessPong(), name: "Pong")

		let ping = try! system.selectActor(pathString: "system/user/Ping")
		XCTAssertNotNil(ping)
		ping ! Ball(sender: nil)
		sleep(5)
		system.stop()
		sleep(2)
	}
}

class Create: Actor.Message {}

class PingParent: Actor {
	override func receive(_ msg: Actor.Message) {
		switch(msg) {
		case is Create:
			let _ = actorOf(Ping(), name: "Ping")
		default:
			print("unexpected message")
		}
	}
}

class PongParent: Actor {
	override func receive(_ msg: Actor.Message) {
		switch(msg) {
		case is Create:
			let _  = actorOf(Pong(), name: "Pong")
		default:
			print("unexpected message")
		}
	}
}

class HeadlessPing : Actor {
    var counter = 0
    
    override func receive(_ msg: Actor.Message) throws {
        switch(msg) {
            case is Ball:
                counter += 1
                print("ping counter: \(counter)")
                Thread.sleepForTimeInterval(1) //Never sleep in an actor, this is for demo!
				let selected = try? selectActor(pathString: "system/user/Pong")
				if let pong = selected {
					pong ! Ball(sender: nil)
				}
            default:
                try super.receive(msg)
        }
    }
}

class HeadlessPong : Actor {
    var counter = 0
    
    override func receive(_ msg: Actor.Message) throws {
        switch(msg) {
        case is Ball:
            counter += 1
            print("pong counter: \(counter)")
            Thread.sleepForTimeInterval(1) //Never sleep in an actor, this is for demo!
			let selected = try? selectActor(pathString: "system/user/Ping")
			if let ping = selected {
				ping ! Ball(sender: nil)
			}
        default:
            try super.receive(msg)
        }
    }
}
