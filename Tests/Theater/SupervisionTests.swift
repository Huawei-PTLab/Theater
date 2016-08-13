import XCTest
import Foundation
@testable import Theater

class SupervisionTests: XCTestCase {

	static var allTests: [(String, (SupervisionTests) -> () throws -> Void)] {
		return [
			("testUnexpectedMessageError", testUnexpectedMessageError)
		]
	}

	func testUnexpectedMessageError() {
		let system = ActorSystem(name: "system")
		let a = system.actorOf(DefaultSupervisor())
		// If test succeeds, error should be thrown and caught by "system/user"
		a ! Foo(sender: nil)
		sleep(1)
	}
}

class CreateChild: Actor.Message {}
class Foo: Actor.Message {}

class DefaultSupervisor: Actor {
	override func receive(_ msg: Actor.Message) throws -> Void {
		switch(msg) {
		default:
			throw TheaterError.unexpectedMessage(msg: msg)
		}
	}
}
