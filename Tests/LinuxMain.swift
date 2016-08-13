import XCTest
@testable import TheaterTestSuite

XCTMain([
	 testCase(SelectActorTests.allTests),
     testCase(TheaterTests.allTests),
	 testCase(SupervisionTests.allTests),
])
