import Theater
import Foundation

private enum Color: Int {
    case BLUE = 0
    case RED
    case YELLOW
    case FADED
}

private class Meet: Actor.Message {
    let from: ActorRef
    let color: Color
    init(from: ActorRef, color: Color, sender: ActorRef? = nil) {
        self.from = from
        self.color = color
        super.init(sender: sender)
    }
}
private class Change: Actor.Message {
    let color: Color
    init(color: Color, sender: ActorRef? = nil) {
        self.color = color
        super.init(sender: sender)
    }
}
private class MeetingCount: Actor.Message {
    let count: Int
    init(count: Int, sender: ActorRef? = nil) {
        self.count = count
        super.init(sender: sender)
    }
}
private class Stop: Actor.Message {}
private class Start: Actor.Message {}

// Global timer
private var startTime = 0.0
private var endTime = 0.0

// Actors
private class Chameneo: Actor {
    let mall: ActorRef
    var color: Color
    let cid: Int
    var meetings = 0
    init(context: ActorCell, mall: ActorRef, color: Color, cid: Int) {
        self.mall = mall
        self.color = color
        self.cid = cid
        super.init(context: context)
    }

    override func receive(_ msg: Actor.Message) {
        switch(msg) {
        case is Start:
            mall ! Meet(from: this, color: self.color, sender: this)
        case let meet as Meet:
            self.color = complement(meet.color)
            self.meetings += 1
            meet.from ! Change(color: self.color)
            self.mall ! Meet(from: this, color: self.color, sender: this)
        case let change as Change:
            self.color = change.color
            self.meetings += 1
            self.mall ! Meet(from: this, color: self.color, sender: this)
        case let stop as Stop:
            self.color = .FADED
            stop.sender! ! MeetingCount(count: self.meetings, sender: this)
        default:
            print("Unexpected message")
        }
    }

    func complement(_ otherColor: Color) -> Color {
        switch(color) {
        case .RED:
            switch(otherColor) {
            case .RED: return .RED
            case .YELLOW: return .BLUE
            case .BLUE: return .YELLOW
            case .FADED: return .FADED
            }
        case .YELLOW:
            switch(otherColor) {
            case .RED: return .BLUE
            case .YELLOW: return .YELLOW
            case .BLUE: return .RED
            case .FADED: return .FADED
            }
        case .BLUE:
            switch(otherColor) {
            case .RED: return .YELLOW
            case .YELLOW: return .RED
            case .BLUE: return .BLUE
            case .FADED: return .FADED
            }
        case .FADED:
            return .FADED
        }
    }
}
private class Mall: Actor {
    var n: Int
    let numChameneos: Int
    var waitingChameneo: ActorRef?
    var sumMeetings: Int = 0
    var numFaded: Int = 0

    init(context: ActorCell, n: Int, numChameneos: Int) {
        self.n = n
        self.numChameneos = numChameneos
        super.init(context: context)
    }

    override func receive(_ msg: Actor.Message) {
        switch(msg) {
        case is Start:
            print("Started: \(Date())")
            startTime = Date().timeIntervalSince1970
            for i in 0..<numChameneos {
                let c = context.actorOf(name: "Chameneo\(i)", { (context: ActorCell) in Chameneo(context: context, mall: self.this, color: Color(rawValue: (i % 3))!, cid: i) })
                c ! Start(sender: this)
            }
        case let mcount as MeetingCount:
            self.numFaded += 1
            self.sumMeetings += mcount.count
            if numFaded == numChameneos {
                endTime = Date().timeIntervalSince1970
                print("Stopped: \(Date())")
                print("Duration: \(endTime - startTime)")
                // should be double of n
                print("Sum meetings: \(self.sumMeetings)")
                // The right way to shut down the system is call shutdown()
                // Calling exit(0) is faster and doesn't matter in a benchmark
                 context.system.shutdown()
                //exit(0)
            }
        case let msg as Meet:
            if self.n > 0 {
                if let waiting = self.waitingChameneo {
                    n -= 1
                    waiting ! msg
                    self.waitingChameneo = nil
                } else {
                    self.waitingChameneo = msg.sender!
                }
            } else {
                if let waiting = self.waitingChameneo {
                    waiting ! Stop(sender: this)
                }
                msg.sender! ! Stop(sender: this)
            }
        default:
            print("Unexpected Message")
        }
    }
}

func chameneos(nChameneos:Int, nHost:Int) {
    print("[Bench] Chameneos \(nChameneos) \(nHost)")
    let system = ActorSystem(name: "chameneos"/*, dispatcher:ShareDispatcher(queues: 4) */)
    let mallActor = system.actorOf(name: "mall", { (context: ActorCell) in Mall(context: context, n: nHost, numChameneos: nChameneos) })
    mallActor ! Start(sender: nil)
    _ = system.waitFor(seconds:6000)	// wait to complete or timeout in 6 mins
}



