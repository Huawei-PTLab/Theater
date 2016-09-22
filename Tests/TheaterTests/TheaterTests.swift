import XCTest
import Foundation
@testable import Theater

class TheaterTests: XCTestCase {
    func testParentChild() {
        let f = Family()
        sleep(1) //Wait for finish
        f.stop()

    }

	func testPingPong() {
		let pp = PingPong()
		sleep(1)
		pp.stop()
		sleep(1)	// wait for the stopping process to finish
	}

	func testGreetings() {
		let sys = GreetingActorController()
		sys.kickoff()
	}

	func testCloudEdge() {
        simpleCase(count:1000)
	}

	static var allTests: [(String, (TheaterTests) -> () throws -> Void)] {
		return [
            //("testParentChild", testParentChild),
			//("testPingPong", testPingPong),
			//("testGreetings", testGreetings),
			("testCloudEdge", testCloudEdge),
		]
	}
}
