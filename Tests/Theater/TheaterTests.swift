import XCTest
import Glibc
@testable import Theater

class TheaterTests: XCTestCase {
	func testPingPong() {
		let pp = PingPong()
		sleep(3)
		pp.stop()
		sleep(3)	// wait for the stopping process to finish
	}

	func testGreetings() {
		let sys = GreetingActorController()
		sys.kickoff()
	}

	func testCloudEdge() {
		let count = 1000
		let system = ActorSystem(name: systemName)
		let _ = system.actorOf(Server(), name: serverName)
		let monitor = system.actorOf(Monitor(), name: monitorName)
		for i in 0..<count {
			let client = system.actorOf(Client(), name: "Client\(i)")
			let timestamp = timeval(tv_sec: 0, tv_usec:0)
			client ! Request(client: i, server: 0, timestamp: timestamp)
			usleep(1000)
		}
		sleep(10)
		monitor ! ShowResult(sender: nil)
		system.stop()
		sleep(2)	// wait to complete
	}

	func testSelectActor() {
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
		sleep(1)
	}

	static var allTests: [(String, (TheaterTests) -> () throws -> Void)] {
		return [
			("PingPong", testPingPong),
			("Greetings", testGreetings),
			("testSelectActor", testSelectActor),
			("CloudEdge", testCloudEdge),
		]
	}
}
