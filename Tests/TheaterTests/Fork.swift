import Theater
import Foundation

// Messages
private class Stop: Actor.Message{}
private class Start: Actor.Message{}
private class TimeStamp: Actor.Message {
    let endTime: Double
    init(end: Double, sender: ActorRef) {
        self.endTime = end
        super.init(sender: sender)
    }
}


private class Node: Actor {

    let currentLevel: Int
    let maxLevel: Int
    let root: ActorRef
    var lChild: ActorRef?
    var rChild: ActorRef?

    init(context: ActorCell, currentLevel: Int, root: ActorRef, maxLevel: Int) {
        self.currentLevel = currentLevel
        self.root = root
        self.maxLevel = maxLevel
        super.init(context: context)
    }

    override func receive(_ msg: Actor.Message) {
        switch(msg) {
        case is Start:
            if currentLevel >= maxLevel {
                // reach the maximum level
                let endTime = Date().timeIntervalSince1970
                root ! TimeStamp(end: endTime, sender: this)
            } else {
                self.lChild = context.actorOf(name: "LN\(currentLevel + 1)", { (context: ActorCell) in Node(context: context, currentLevel: self.currentLevel + 1, root: self.root, maxLevel: self.maxLevel) })
                self.rChild = context.actorOf(name: "RN\(currentLevel + 1)", { (context: ActorCell) in Node(context: context, currentLevel: self.currentLevel + 1, root: self.root, maxLevel: self.maxLevel) })
                self.lChild! ! Start(sender: nil)
                self.rChild! ! Start(sender: nil)
            }
        case is Stop:
            if let left = self.lChild {
                left ! Stop(sender: nil)
            }
            if let right = self.rChild {
                right ! Stop(sender: nil)
            }
        default:
            print("Unexpected message")
        }
    }
}

private class RootNode: Actor {
    var timeStampCount = 0
    let startTime: Double = Date().timeIntervalSince1970
    var endTime: Double = 0.0
    var lChild: ActorRef?
    var rChild: ActorRef?
    let maxLevel: Int

    required init(context: ActorCell, maxLevel: Int) {
        self.maxLevel = maxLevel
        super.init(context: context)
    }

    override func receive(_ msg: Actor.Message) {
        switch(msg) {
        case is Start:
            print("Started: \(Date())")
            if maxLevel == 1 {
                let endTime = Date().timeIntervalSince1970
                this ! TimeStamp(end: endTime, sender: this)
            } else {
                self.lChild = context.actorOf(name: "LN2", { (context: ActorCell) in Node(context: context, currentLevel: 2, root: self.this, maxLevel: self.maxLevel) })
                self.rChild = context.actorOf(name: "RN2", { (context: ActorCell) in Node(context: context, currentLevel: 2, root: self.this, maxLevel: self.maxLevel) })
                self.lChild! ! Start(sender: nil)
                self.rChild! ! Start(sender: nil)
            }
        case let timestamp as TimeStamp:
            if timestamp.endTime > self.endTime {
                self.endTime = timestamp.endTime
            }
            self.timeStampCount += 1
            if self.timeStampCount == Int(pow(2.0, Double(maxLevel - 1))) {
                print("Finished: \(Date())")
                print("Duration: \(self.endTime - self.startTime)")
                // The right way to shut down the system is call shutdown()
                // Calling exit(0) is faster and doesn't matter in a benchmark
                context.system.shutdown()
                //exit(0)
            }
        default:
            print("Unexpected message")
        }
    }
}

func fork(maxLevel:Int) {
    //let maxLevel = Int(CommandLine.arguments[1])!
    print("[Bench] Fork \(maxLevel)")
    let system = ActorSystem(name: "fork"/*, dispatcher:ShareDispatcher(queues: 4) */)
    let root = system.actorOf(name: "root", { (context: ActorCell) in RootNode(context: context, maxLevel: maxLevel) })
    root ! Start(sender: nil)
    _ = system.waitFor(seconds:3000) // wait to complete or timeout in 3000s
}



