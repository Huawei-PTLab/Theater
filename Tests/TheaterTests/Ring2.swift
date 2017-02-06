import Theater
import Foundation

// Messages
private class Start: Actor.Message {}
private class Stop: Actor.Message {}
private class Connect: Actor.Message {
    let next: ActorRef

    init(_ next: ActorRef, sender: ActorRef?) {
        self.next = next
        super.init(sender: sender)
    }
}
private class Token: Actor.Message {
    let id: Int
    let value: Int

    init(id: Int, value: Int, sender: ActorRef?) {
        self.id = id
        self.value = value
        super.init(sender: sender)
    }
}

// Global timer
private var startTime: Double = 0.0
private var endTime: Double = 0.0

private class NodeActor: Actor {
    var nextNode: ActorRef!	= nil
    let nodeId: Int
    let initValue: Int

    required init(context: ActorCell, args: [Int]) {
        self.nodeId = args[0]
        self.initValue = args[1]
        super.init(context: context)
    }

    override func receive(_ msg: Actor.Message) {
        switch(msg) {
        case let connect as Connect:
            self.nextNode = connect.next
        case is Start:
            startTime = Date().timeIntervalSince1970
            print("Start: \(Date())")
            nextNode ! Token(id: nodeId, value: initValue, sender: this)
        case let token as Token:
            if token.value == 0 {
                endTime = Date().timeIntervalSince1970
                print(nodeId)
                print("Stop: \(Date())")
                print("Duration: \(endTime - startTime)")
                // The right way to shut down the system is call shutdown()
                // Calling exit(0) is faster and doesn't matter in a benchmark
                context.system.shutdown()
                //exit(0)
            } else {
                nextNode ! Token(id: token.id, value: token.value - 1, sender: this)
            }
        default:
            print("Actor \(nodeId) got unexpected message: \(msg)")
        }
    }
}

func ring2(nNodes:Int, initValue:Int) {
    //let nNodes = Int(CommandLine.arguments[1])!
    //let initValue = Int(CommandLine.arguments[2])!
    print("[Bench] Ring2 \(nNodes) \(initValue)")
    print("Ring size: \(nNodes)")
    print("Initial message value: \(initValue)")
    let system = ActorSystem(name: "Ring"/*, dispatcher:ShareDispatcher(queues: 4) */)
    var nodes = [ActorRef]()

    for i in 0..<nNodes {
        let node = system.actorOf(name: "Node\(i)") {
            context in NodeActor(context:context, args:[i, initValue])
        }
        nodes.append(node)
    }

    for i in 0..<nNodes {
        nodes[i] ! Connect(nodes[(i+1)%nNodes], sender: nil)
    }

    nodes[0] ! Start(sender: nil)

    _ = system.waitFor(seconds:300)	// wait to complete or timeout in 6 mins

}
