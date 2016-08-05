import Dispatch 
import Foundation

public protocol Dispatcher {
	func assignQueue() -> dispatch_queue_t
	func assignQueue(name: String) -> dispatch_queue_t
}

/**
	Assign a new dispatch_queue every time
*/
public class DefaultDispatcher: Dispatcher {
	public func assignQueue() -> dispatch_queue_t {
		return dispatch_queue_create("", nil)
	}	

	public func assignQueue(name: String) -> dispatch_queue_t {
		return dispatch_queue_create(name, nil)
	}
}

/**
	Share queues between actors
*/
public class ShareDispatcher: Dispatcher {
	/** 
		Ensure thead-safe access to type properties
	*/
	let systemQueue = dispatch_queue_create("system", nil)
	var queues = [dispatch_queue_t]()
	var randomQueue: dispatch_queue_t? = nil
	let maxQueues = 10000
	var queueCount = 0

	public init() {
		srandom(UInt32(NSDate().timeIntervalSince1970))
	}

	public func assignQueue() -> dispatch_queue_t {
		if queueCount < maxQueues {
			let newQueue = dispatch_queue_create("", nil)
			if randomQueue == nil { randomQueue = newQueue }
			queueCount += 1
			dispatch_async(systemQueue) { () in 
				self.queues.append(newQueue)
				let randomNumber = Int(rand())
				if randomNumber % 2 == 0 {
					self.randomQueue = newQueue
				}
			}
			return newQueue
		} else {
			dispatch_async(systemQueue) { () in 
				let randomNumber = Int(rand()) % self.maxQueues
				self.randomQueue = self.queues[randomNumber]
			}
			return randomQueue!
		}
	}

	public func assignQueue(name: String) -> dispatch_queue_t {
		return dispatch_queue_create(name, nil)
	}
}
