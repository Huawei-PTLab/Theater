import XCTest
import Foundation
@testable import Theater

class SupervisionTests: XCTestCase {

	static var allTests: [(String, (SupervisionTests) -> () throws -> Void)] {
		return [
			("testUnexpectedMessageError", testUnexpectedMessageError),
			("testRestart", testRestart),
		]
	}

	func testUnexpectedMessageError() {
		let system = ActorSystem(name: "system")
		let a = system.actorOf({DefaultSupervisor()}, name: "DefaultSupervisor")
		// If test succeeds, error should be thrown and caught by "system/user"
		a ! Foo(sender: nil)
		sleep(1)
	}

	func testRestart() {
		let system = ActorSystem(name: "testRestart")
		let parent = system.actorOf({CounterActorSupervisor()}, name: "supervisor")
		parent ! CreateChild(sender: nil)
		let counter = try! system.selectActor(pathString:"testRestart/user/supervisor/counter")
		for i in 1...10 {
			if i % 3 == 0 {
				// Once every 3 messages, send a Foo to trigger restart.
				counter ! Foo(sender: nil)
			} else {
				counter ! Increment(sender: nil)
			}
			// we need to sleep between messages because supervisor needs time to react to the 
			// error messages from child
			usleep(100)
		}
		sleep(2)
	}
}

class CreateChild: Actor.Message {}
class Foo: Actor.Message {}
class Increment: Actor.Message {}

class DefaultSupervisor: Actor {
	override func receive(_ msg: Actor.Message) throws -> Void {
		switch(msg) {
		default:
			throw TheaterError.unexpectedMessage(msg: msg)
		}
	}
}

class CounterActorSupervisor: Actor {
	override func receive(_ msg: Actor.Message) throws -> Void {
		switch(msg) {
		case is CreateChild:
			let _ = actorOf({CounterActor(start: 0)}, name: "counter")
		default:
			throw TheaterError.unexpectedMessage(msg: msg)
		}
	}
}

class CounterActor: Actor {
	var counter: Int
	init(start: Int) {
		counter = start
	}
	override func receive(_ msg: Actor.Message) throws -> Void {
		switch(msg) {
		case is Increment:
			counter += 1
			print("counter: \(counter)")
		default:
			throw TheaterError.unexpectedMessage(msg: msg)
		}
	}
}
