import Glibc
import Foundation

public protocol Queue {
    associatedtype T
    mutating func enqueue(item:T)
    mutating func dequeue() -> T?
}

public struct FastQueue<T> : Queue {
    private var ptr: UnsafeMutablePointer<T>
    private var size: Int

    init(initSize: Int) {
        size = initSize
        ptr = UnsafeMutablePointer<T>.allocate(capacity:size)
    }

    private var rear = 0
    private var front = 0
    private var count = 0

    private mutating func expand() {
        let newSize = size * 2
        let newPtr = UnsafeMutablePointer<T>.allocate(capacity:newSize)

        if front == 0 || front < rear {
            newPtr.initialize(from:ptr+front, count:size)
            rear = size
        } else {
            newPtr.initialize(from:ptr+front, count:(size-front))
            (newPtr+size-front).initialize(from:ptr, count:front)
            front = 0
            rear = size
        }
        ptr.deinitialize(count:size)
        ptr.deallocate(capacity:size)
        ptr = newPtr
        size = newSize
    }

    public mutating func enqueue(item:T) {
        if count == size { expand() }

        (ptr + rear).initialize(to:item)
        rear = (rear + 1) % size
        count += 1
    }

    public mutating func dequeue() -> T? {
        guard count > 0 else { return nil }
        let item = (ptr + front).pointee
        (ptr + front).deinitialize()
        front = (front + 1) % size
        count -= 1
        return item
    }
}

public struct Stack<A> {
    private var array: [A]

    public init() { self.array = [A]() }

    public mutating func push(element: A) {
        self.array.append(element)
    }

    public mutating func replaceHead(element: A) -> A? {
        if self.array.count == 0 {
            self.array.append(element)
            return nil
        } else {
            let old = self.array[array.count - 1]
            self.array[array.count - 1] = element
            return old
        }
    }

    public func head() -> A? { return self.array.last }
}

public protocol Message : CustomStringConvertible {
    var sender: ActorRef? { get set }
}

public struct Harakiri : Message {
    public var sender: ActorRef?

    public init(sender: ActorRef?) { self.sender = sender }

    public var description: String { return "<Harakiri>" }
}

public struct PoisonPill : Message {
    public var sender: ActorRef?

    public init(sender: ActorRef?) { self.sender = sender }

    public var description: String { return "<PoisonPill>" }
}

public typealias Receive = (Message) -> (Void)

public protocol Actor {
    var statesStack: Stack<(String,Receive)>* { get set }
    var mailbox: FastQueue<Message> { get set }
    var inTaskQueue: Bool { get set }
    var _ref: ActorRef? { get set }

    mutating func processMessage()
    func stop()
    mutating func stop(_ actorRef: inout ActorRef)
    mutating func actorOf(_ actorInstance: Actor*, name: String) -> ActorRef
    func become(_ name: String, state: @escaping Receive, discardOld: Bool)
    mutating func systemReceive(_ realMsg: Message)
    mutating func receive(_ msg: Message)
    mutating func tell(_ msg: Message)
    func preStart()
    func willStop()
}

extension Actor {
    internal mutating func processMessage() {
        while let msg = mailbox.dequeue() {
            systemReceive(msg)
        }
        inTaskQueue = false
    }

    public var this: ActorRef {
        get {
            if let ref = self._ref {
                return ref
            } else {
                print("ERROR: nil _ref, terminating system")
                exit(1)
            }
        }
        set { self._ref = newValue }
    }

    public func stop() { this ! Harakiri(sender: nil) }

    public mutating func stop(_ actorRef: inout ActorRef) {
        let path = actorRef.path.asString
        self.this.children.removeValue(forKey: path)
        this.context.allActors.removeValue(forKey: path)
        //actorRef.actorInstance = nil
    }

    public mutating func actorOf(_ actorInstance: Actor*, name: String) -> ActorRef {
        let completePath = "\(self.this.path.asString)/\(name)"
        let ref = ActorRef(path: ActorPath(path: completePath),
                           actorInstance: actorInstance,
                           context: this.context)
        actorInstance._ref = ref
        self.this.children[completePath] = ref
        this.context.allActors[completePath] = ref
        actorInstance.preStart()
        return ref
    }

    public func become(_ name: String, state: @escaping Receive, discardOld: Bool) {
        if discardOld {
            let _ = self.statesStack.replaceHead(element: (name, state))
        } else {
            self.statesStack.push(element: (name, state))
        }
    }

    public mutating func systemReceive(_ realMsg: Message) {
        switch realMsg {
        case is Harakiri, is PoisonPill:
            self.willStop()
            self.this.children.forEach({ (_,actorRef) in
                actorRef ! Harakiri(sender: this)
            })
        default:
            if let (name, state): (String, Receive) = self.statesStack.head() {
                #if DEBUG
                print("Sending message to state \(name)")
                #endif
                state(realMsg)
            } else {
                self.receive(realMsg)
            }
        }
    }

    public mutating func receive(_ msg: Message) { print("Default receive") }

    public mutating func tell(_ msg: Message) {
        mailbox.enqueue(item:msg)
        if !inTaskQueue {
            inTaskQueue = true
            processMessage()
        }
    }

    public func preStart() { }

    public func willStop() { }
}

struct Supervisor : Actor {
    var statesStack: Stack<(String,Receive)>* = Stack*()
    var mailbox = FastQueue<Message>(initSize: 10)
    var inTaskQueue = false
    var _ref: ActorRef?
}

public struct ActorPath {
    public let asString: String

    public init(path: String) { self.asString = path }
}

public struct ActorRef : CustomStringConvertible {
    public var description: String {
        return "<\(type(of: self)): \(path.asString)>"
    }

    internal var context: ActorSystem*
    internal var children = Hashtable<String, ActorRef>()
    public let path: ActorPath
    internal var actorInstance: Actor*

    internal init(path: ActorPath, actorInstance: Actor*, context: ActorSystem*) {
        self.path = path
        self.actorInstance = actorInstance
        self.context = context
        #if DEBUG
        print("Creating Actor \(path.asString)")
        #endif
    }

    public func tell(_ msg: Message) {
        actorInstance.tell(msg)
    }

    internal func stop(_ ref: inout ActorRef) {
        actorInstance.stop(&ref)
    }
}

infix operator ! : SendMessagePrecedence
precedencegroup SendMessagePrecedence { associativity : left }

@_transparent
public func !(actorRef: ActorRef, msg: Message) {
    actorRef.tell(msg)
}

public struct ActorSystem {
    var supervisor: ActorRef!

    public let name: String
    public var allActors = [String : ActorRef]()

    public init(name: String) { self.name = name }

    public func stop(_ actorRef: ActorRef) { }

    public func stop() {
        supervisor ! Harakiri(sender: nil)
        print("ActorSystem \(name) terminated")
    }

    public func actorOf(_ actorInstance: Actor*, name: String) -> ActorRef {
        return supervisor.actorInstance.actorOf(actorInstance, name: name)
    }

    public static func create(_ name: String) -> ActorSystem* {
        let system = ActorSystem*(name: name)
        // This fails because we can't convert S* to P*
        //let supervisorActor = Supervisor*()
        let supervisorActor = SharePointer<Actor>(Supervisor())
        let ref = ActorRef(path: ActorPath(path: "\(name)"),
                           actorInstance: supervisorActor,
                           context: system)
        supervisorActor._ref = ref
        system.supervisor = ref
        return system
    }
}

public struct Hashtable<K: Hashable, V> : CustomStringConvertible {
    private var tableSize = 2
    private var elementNum = 0

    private var keys: UnsafeMutablePointer<K>
    private var values: UnsafeMutablePointer<V>
    private var occupied: UnsafeMutablePointer<Bool>
    private var relocatedTo: UnsafeMutablePointer<[Int]>

    public init(count: Int = 2) {
        while tableSize < count  { tableSize <<= 1 }
        self.keys = UnsafeMutablePointer<K>.allocate(capacity: tableSize)
        self.values = UnsafeMutablePointer<V>.allocate(capacity: tableSize)
        self.occupied = UnsafeMutablePointer<Bool>.allocate(capacity: tableSize)
        self.relocatedTo = UnsafeMutablePointer<[Int]>.allocate(capacity: tableSize)
        for i in 0..<tableSize {
            (self.occupied + i).initialize(to: false)
            (self.relocatedTo + i).initialize(to: [])
        }
    }

    var count: Int { return elementNum }

    mutating public func set(key: K, value: V) -> Bool {
        let sizeMinus1 = (tableSize - 1)
        var index = key.hashValue & sizeMinus1
        let origIndex = index
        var probe = 0

        while true {
            // case 1: the desired bucket is empty -> insert new entry
            if !self.occupied[index] {
                (self.keys + index).initialize(to: key)
                (self.values + index).initialize(to: value)
                self.occupied[index] = true
                if probe != 0 {
                    self.relocatedTo[origIndex].append(index)
                }
                elementNum += 1

                // Grow the table if we are about to use up space
                if self.count >= (sizeMinus1 * 7 / 10) {
                    enlarge()
                }
                return true
            }
            // case 2: the desired bucket is taken by the same key -> update value
            else if self.keys[index] == key {
                self.values[index] = value
                return false
            }
            // case 3: collision! -> use quadratic probing to find an available bucket
            else {
                probe += 1
                index = (index + probe) & sizeMinus1
                assert(probe < tableSize, "Failed to grow the table earlier")
            }
        }
    }

    private func findIndex(key: K) -> Int {
        let index = key.hashValue & (tableSize - 1)

        // case 1: the bucket is empty -> return not found
        // We can do this because the move we did in remove function
        if !self.occupied[index] { return -1 }

        // case 2: the desired bucket is taken by the same key -> return key index
        if self.keys[index] == key { return index }

        // case 3: collision! -> use relocatedTo array to find its real location
        for i in 0..<self.relocatedTo[index].count {
            let relocatedIndex = self.relocatedTo[index][i]
            if self.keys[relocatedIndex] == key {
                return relocatedIndex
            }
        }

        // case 4: searched all table -> not found
        return -1
    }

    mutating private func findAndRemoveRelocateIndex(key: K) -> Int {
        let index = key.hashValue & (tableSize - 1)

        // case 1: the bucket is empty -> return not found
        // We can do this because the move we did in remove function
        if !self.occupied[index] {
            return -1
        }

        // case 2: the desired bucket is taken by the same key -> return key index
        if self.keys[index] == key {
            return index
        }

        // case 3: collision! -> use relocatedTo array to find its real location
        for i in 0..<self.relocatedTo[index].count {
            let relocatedIndex = self.relocatedTo[index][i]
            if self.keys[relocatedIndex] == key {
                self.relocatedTo[index].remove(at: i)
                return relocatedIndex
            }
        }

        // case 4: searched all table -> not found
        return -1
    }

    public func get(key: K) -> V? {
        let index = findIndex(key:key)
        if index != -1 { return self.values[index] }
        return nil
    }

    mutating public func remove(key: K) -> Bool {
        var index = findAndRemoveRelocateIndex(key:key)
        if index != -1 {
            elementNum -= 1

            // move a collided entry to here if there is one
            while !self.relocatedTo[index].isEmpty {
                let relocatedToIndex = self.relocatedTo[index].popLast()!

                // move the KV pair
                self.keys[index] = self.keys[relocatedToIndex]
                self.values[index] = self.values[relocatedToIndex]

                // deal with the hole left by the above moving
                index = relocatedToIndex
            }
            self.occupied[index] = false // mark the bucket as empty
            // free the value and key
            (self.values + index).deinitialize()
            (self.keys + index).deinitialize()

            return true
        }
        return false
    }

    mutating public func removeValue(forKey: K) {
        let _ = remove(key: forKey)
    }

    public func isEmpty() -> Bool { return self.count == 0 }

    public func forEachValue(_ lambda: (V)->()) {
        for i in 0..<tableSize {
            if occupied[i] {
                lambda(values[i])
            }
        }
    }

    public func forEachKey(_ lambda: (K)->()) {
        for i in 0..<tableSize {
            if occupied[i] {
                lambda(keys[i])
            }
        }
    }

    public func forEach(_ lambda: (K, V)->()) {
        for i in 0..<tableSize {
            if occupied[i] {
                lambda(keys[i], values[i])
            }
        }
    }

    mutating public func enlarge() { return enlarge(toSize: tableSize * 4) }

    mutating public func enlarge(toSize: Int) {
        let origSize = tableSize
        while tableSize < toSize  { tableSize <<= 1 }

        let newKeys = UnsafeMutablePointer<K>.allocate(capacity: tableSize)
        let newValues = UnsafeMutablePointer<V>.allocate(capacity: tableSize)
        let newFlags = UnsafeMutablePointer<Bool>.allocate(capacity: tableSize)
        let newRelocations = UnsafeMutablePointer<[Int]>.allocate(capacity: tableSize)
        for i in 0..<tableSize {
            (newFlags + i).initialize(to: false)
            (newRelocations + i).initialize(to: [])
        }

        for i in 0..<origSize {
            if self.occupied[i] {
                let key = self.keys[i]
                let value = self.values[i]
                var probe = 0;             // how many times we've probed
                let sizeMinus1 = tableSize - 1;
                var index = key.hashValue & sizeMinus1;
                let origIndex = index

                while probe < tableSize {
                    if !newFlags[index] { break }
                    probe += 1
                    index = (index + probe) & sizeMinus1
                }
                assert(probe < tableSize, "Error: Hash table gets full during enlarging");

                (newKeys + index).initialize(to: key)
                (newValues + index).initialize(to: value)
                newFlags[index] = true
                if probe != 0 {
                    newRelocations[origIndex].append(index)
                }
            }
        }

        self.keys.deallocate(capacity: origSize)
        self.values.deallocate(capacity: origSize)
        self.occupied.deallocate(capacity: origSize)
        self.relocatedTo.deallocate(capacity: origSize)

        self.keys = newKeys
        self.values = newValues // TODO: make array copy more efficient with ownership
        self.occupied = newFlags
        self.relocatedTo = newRelocations
    }

    public var description: String {
        get {
            if elementNum == 0 { return "[]"}
            var str = "["
            for i in 0..<tableSize {
                if occupied[i] {
                    let key = self.keys[i]
                    let value = self.values[i]
                    if str != "[" { str += ", "}
                    str += String(describing: key) + ": " + String(describing: value)
                }
            }
            str += "]"
            return str
        }
    }

    subscript(key: K) -> V? {
        get {
            return get(key: key)
        }
        set {
            if let value = newValue {
                let _ = set(key: key, value: value)
            } else {
                let _ = remove(key: key)
            }
        }
    }
}

// ----------------------------------------------------------------
// Test code begins here
// ----------------------------------------------------------------

let systemName = "CloudEdgeUSN"
let serverName = "Server"
let monitorName = "Monitor"

public func latencyFrom(_ begin: timeval) -> Double {
    var now = timeval(tv_sec: 0, tv_usec: 0)
    gettimeofday(&now, nil)
    return difftime(now.tv_sec, begin.tv_sec)*1000000 + Double(now.tv_usec - begin.tv_usec)
}

struct Request : Message {
    var sender: ActorRef?
    let client: Int
    let server: Int
    var timestamp: timeval

    init(client: Int, server: Int, timestamp: timeval, sender: ActorRef? = nil) {
        self.sender = sender
        self.client = client
        self.server = server
        self.timestamp = timestamp
    }

    var description: String {
        return "<\(type(of:self)): client=\(client), server=\(server), timestamp=\(timestamp)>"
    }
}

struct Response : Message {
    var sender: ActorRef?
    let client: Int
    let server: Int
    var timestamp: timeval

    init(client: Int, server: Int, timestamp: timeval, sender: ActorRef? = nil) {
        self.sender = sender
        self.client = client
        self.server = server
        self.timestamp = timestamp
    }

    var description: String {
        return "<\(Response.self): client=\(client) server=\(server) timestamp=\(timestamp)>"
    }
}

struct Notification : Message {
    var sender: ActorRef?
    let client: Int
    let server: Int

    init(client: Int, server: Int, sender: ActorRef? = nil) {
        self.sender = sender
        self.client = client
        self.server = server
    }

    var description: String {
        return "<\(Notification.self): client=\(client) server=\(server)>"
    }
}

struct ShowResult : Message {
    var sender: ActorRef?

    public init(sender: ActorRef?) { self.sender = sender }

    public var description: String { return "<ShowResult>" }
}

struct RecordResult : Message {
    var sender: ActorRef?
    let client: Int
    let latency: Double

    init(client: Int, latency: Double, sender: ActorRef? = nil) {
        self.sender = sender
        self.client = client
        self.latency = latency
    }

    var description: String {
        return "<\(RecordResult.self): client=\(client) latency=\(latency)>"
    }
}

struct Client : Actor {
    var statesStack: Stack<(String,Receive)>* = Stack*()
    var mailbox = FastQueue<Message>(initSize: 10)
    var inTaskQueue = false
    var _ref: ActorRef?

    let server: ActorRef
    let monitor: ActorRef

    init(server:ActorRef, monitor:ActorRef) {
        self.server = server
        self.monitor = monitor
    }

    func preStart() {
        self.become("idle", state: self.idle, discardOld: true)
    }

    func idle(msg: Message) {
        switch msg {
        case let request as Request:
            var req = Request(client: request.client, server: request.server,
                              timestamp: request.timestamp, sender: self.this)
            gettimeofday(&req.timestamp, nil)
            self.server ! req
            self.become("waitResponse", state: self.waitResponse, discardOld: true)
            #if DEBUG
            print("\(Client.self).\(#function): recv \(request) from \(request.sender)")
            print("\(Client.self).\(#function): sent \(req) to \(self.server)")
            #endif
        default:
            break
        }
    }

    func waitResponse(msg: Message) {
        switch msg {
        case let response as Response:
            let latency = latencyFrom(response.timestamp)
            let record = RecordResult(client: response.client, latency: latency, sender: self.this)
            self.monitor ! record

            let notification = Notification(client: response.client, server: response.server, sender: self.this)
            self.server ! notification
            #if DEBUG
            print("\(Client.self).\(#function): recv \(response) from \(response.sender)")
            print("\(Client.self).\(#function): sent \(record) to \(self.monitor)")
            print("\(Client.self).\(#function): sent \(notification) to \(self.server)")
            #endif
            self.stop()
        default:
            break
        }
    }
}

struct Server : Actor {
    var statesStack: Stack<(String,Receive)>* = Stack*()
    var mailbox = FastQueue<Message>(initSize: 10)
    var inTaskQueue = false
    var _ref: ActorRef?

    var activeContainer = [Int : ActorRef]()
    var index = 0

    mutating func receive(_ m: Message) {
        switch m {
        case let request as Request:
            if let container = self.activeContainer[request.server] {
                container ! request
                #if DEBUG
                print("\(Server.self).\(#function): sent \(request) to \(container)")
                #endif
            } else {
                index += 1
                //let container = actorOf(Container(), name: String(format: "Container%d", index))
                let containerShare = SharePointer<Actor>(Container())
                let container = actorOf(containerShare, name: String(format: "Container%d", index))
                activeContainer[index] = container
                #if DEBUG
                print("\(Server.self).\(#function): create new container \(container)")
                print("latency till server sending to container: \(latencyFrom(request.timestamp))")
                #endif
                container ! Request(client: request.client, server: index,
                                    timestamp: request.timestamp, sender: request.sender)
                #if DEBUG
                print("\(Server.self).\(#function): sent \(request) to \(container)")
                #endif
            }

        case let notification as Notification:
            let containerp = activeContainer[notification.server]
            #if DEBUG
            print("\(Server.self).\(#function): recv \(notification) from \(notification.sender)")
            #endif
            if let container = containerp {
                let poisonPill = PoisonPill(sender: self.this)
                container ! notification
                container ! poisonPill
                #if DEBUG
                print("\(Server.self).\(#function): sent \(notification) to \(container)")
                print("\(Server.self).\(#function): sent \(poisonPill) to \(container)")
                #endif
                activeContainer.removeValue(forKey: notification.server)
            }
        default:
            break
        }
    }
}

struct Container : Actor {
    var statesStack: Stack<(String,Receive)>* = Stack*()
    var mailbox = FastQueue<Message>(initSize: 10)
    var inTaskQueue = false
    var _ref: ActorRef?

    func preStart() {
        self.become("idle", state: self.idle, discardOld: true)
    }

    func idle(msg: Message) {
        switch msg {
        case let request as Request:
            #if DEBUG
            print("\(Container.self).\(#function): client=\(request.client) server=\(request.server), timestamp=\(request.timestamp)")
            print("latency till container sending to client: \(latencyFrom(request.timestamp))")
            #endif
            let response = Response(client: request.client, server: request.server, timestamp: request.timestamp, sender: self.this)
            if let sender = request.sender {
                sender ! response
                self.become("waitNotification", state: self.waitNotification, discardOld: true)
                #if DEBUG
                print("\(Container.self).\(#function): sent \(response) to \(sender)")
                #endif
            } else {
                assert(false, "sender does not exist")
            }
        default:
            break
        }
    }

    func waitNotification(msg: Message) {
        self.become("idle", state: self.idle, discardOld: true)
        #if DEBUG
        print("\(Container.self).\(#function): recv \(msg) from \(msg.sender)")
        #endif
    }
}

struct Monitor : Actor {
    var statesStack: Stack<(String,Receive)>* = Stack*()
    var mailbox = FastQueue<Message>(initSize: 10)
    var inTaskQueue = false
    var _ref: ActorRef?

    var latencyRecord = [(Int, Double)]()

    mutating func receive(_ m: Message) {
        switch m {
        case let msg as RecordResult:
            latencyRecord.append((msg.client, msg.latency))
        case is ShowResult:
            var sum: Double = 0
            var min: Double = 10000000
            var max: Double = 0
            if latencyRecord.count != 0 {
                for r in latencyRecord {
                    sum += r.1
                    min = r.1 < min ? r.1 : min
                    max = r.1 > max ? r.1 : max
                    #if DUMP_LATENCIES
                    print(String(format: "%3d %10.1f", r.0, r.1))
                    #endif
                }

                print(String(format: "%10.1f %10.1f %10.1f", min, sum/Double(latencyRecord.count), max))
            }
        default:
            print("unexpected message \(m)")
        }
        #if DEBUG
        print("\(Monitor.self).\(#function): recv \(m) from \(m.sender)")
        #endif
    }
}

func simpleCase(count:Int) {
    let system = ActorSystem.create(systemName)
    //let server = system.actorOf(Server*(), name: serverName)
    let serverShare = SharePointer<Actor>(Server())
    let server = system.actorOf(serverShare, name: serverName)
    //let monitor = system.actorOf(Monitor*(), name: monitorName)
    let monitorShare = SharePointer<Actor>(Monitor())
    let monitor = system.actorOf(monitorShare, name: monitorName)
    for i in 0..<count {
        //let client = system.actorOf(Client*(server: server, monitor: monitor), name: "Client\(i)")
        let clientShare = SharePointer<Actor>(Client(server: server, monitor: monitor))
        let client = system.actorOf(clientShare, name: "Client\(i)")
        let timestamp = timeval(tv_sec: 0, tv_usec:0)
        client ! Request(client: i, server: 0, timestamp: timestamp)
        usleep(1000)
    }
    sleep(3)
    monitor ! ShowResult(sender: nil)
    system.stop()
    sleep(2)
}

simpleCase(count:1000)
