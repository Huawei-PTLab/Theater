import Glibc
import XCTest
func testPingpong() {
    let pp = PingPong()
    sleep(3)
    pp.stop()
}
testPingpong()
