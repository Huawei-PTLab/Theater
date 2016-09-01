//
// Copyright (c) 2016 Huawei PT-Lab Open Source project authors.
// Licensed under Apache License v2.0
//
// CloudEdge.swift
// A simple Client/Server Actor system test case
//

import Theater
import Foundation

let systemName = "CloudEdgeUSN"
let userName = "user"
let serverName = "Server"
let monitorName = "Monitor"

class Request: Actor.Message {
    let client: Int
    let server: Int
    var timestamp: timeval
    init(client: Int, server: Int, timestamp: timeval, sender: Optional<ActorRef> = nil){
        self.client = client
        self.server = server
        self.timestamp = timestamp
        super.init(sender: sender)
    }
    override var description : String {
        get {
            return "<\(type(of:self)): client=\(client), server=\(server), timestamp=\(timestamp)>"
        }
    }
}
class Response: Actor.Message {
    let client: Int
    let server: Int
    var timestamp: timeval
    init(client: Int, server: Int, timestamp: timeval, sender: Optional<ActorRef> = nil){
        self.client = client
        self.server = server
        self.timestamp = timestamp
        super.init(sender: sender)
    }
    override var description: String {
        get {
            return "<\(Response.self): client=\(client) server=\(server) timestamp=\(timestamp)>"
        }
    }
}

class Notification: Actor.Message {
    let client: Int
    let server: Int
    init(client: Int, server: Int, sender: Optional<ActorRef> = nil){
        self.client = client
        self.server = server
        super.init(sender: sender)
    }
    override var description: String {
        get {
            return "<\(Notification.self): client=\(client) server=\(server)>"
        }
    }
}
class ShowResult: Actor.Message {}
class RecordResult: Actor.Message {
    let client: Int
    let latency: Double
    init(client: Int, latency: Double, sender: Optional<ActorRef> = nil) {
        self.client = client
        self.latency = latency
        super.init(sender: sender)
    }
    override var description: String {
        get {
            return "<\(RecordResult.self): client=\(client) latency=\(latency)>"
        }
    }
}


class Client: Actor {
    static let serverPath = "\(systemName)/\(userName)/\(serverName)"
    static let monitorPath = "\(systemName)/\(userName)/\(monitorName)"
    lazy var server: ActorRef? = {
        return try? self.selectActor(pathString: Client.serverPath)
    }()
    lazy var monitor: ActorRef? = {
        return try? self.selectActor(pathString: Client.monitorPath)
    }()

    override func preStart() -> Void {
        super.preStart()
        self.become("idle", state: self.idle(), discardOld: true)
    }
    func idle() -> Receive {
        return { [unowned self] (msg: Message) in
                   switch (msg){
                   case let request as Request:
                       let req = Request(client: request.client, server: request.server,
                                         timestamp: request.timestamp, sender: self.this)
                       gettimeofday(&req.timestamp, nil)
                       self.server! ! req
                       self.become("waitResponse", state: self.waitResponse(), discardOld: true)
                       #if DEBUG
                       print("\(Client.self).\(#function): recv \(request) from \(request.sender)")
                       print("\(Client.self).\(#function): sent \(req) to \(self.server)")
                       #endif
                   default:
                       break
                   }
               }
    }
    func waitResponse() -> Receive {
        return { [unowned self] (msg: Message) in
                   switch msg {
                   case let response as Response:
                       var now = timeval(tv_sec: 0, tv_usec: 0)

                       gettimeofday(&now, nil)
                       let latency = difftime(now.tv_sec, response.timestamp.tv_sec)*1000000
                                     + Double(now.tv_usec - response.timestamp.tv_usec)
                       let record = RecordResult(client: response.client, latency: latency, sender: self.this)
                       self.monitor! ! record

                       let notification = Notification(client: response.client, server: response.server, sender: self.this)
                       self.server! ! notification
                       #if DEBUG
                           print("\(Client.self).\(#function): recv \(response) from \(response.sender)")
                           print("\(Client.self).\(#function): sent \(record) to \(self.monitor!)")
                           print("\(Client.self).\(#function): sent \(notification) to \(self.server!)")
                       #endif
                       self.stop()
                   default:
                       break
                   }
               }
    }
}
class Server: Actor {
    final var activeContainer = [Int : ActorRef]()
    var index = 0
    override func receive(_ m: Actor.Message) {
        switch (m) {
        case let request as Request:
            if let container = self.activeContainer[request.server] {
                container ! request
                #if DEBUG
                print("\(Server.self).\(#function): sent \(request) to \(container)")
                #endif
            } else {
                index += 1
                let container = actorOf(Container.init, name: String(format: "Container%d", index))
                activeContainer[index] = container
                #if DEBUG
                    print("\(Server.self).\(#function): create new container \(container)")
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


class Container: Actor {
    override func preStart() -> Void {
        super.preStart()
        self.become("idle", state: self.idle(), discardOld: true)
    }
    func idle() -> Receive {
        return { [unowned self] (msg: Message) in
                   switch (msg){
                   case let request as Request:
                       #if DEBUG
                       print("\(Container.self).\(#function): client=\(request.client) server=\(request.server), timestamp=\(request.timestamp)")
                       #endif
                       let response = Response(client: request.client, server: request.server, timestamp: request.timestamp, sender: self.this)
                       if let sender = request.sender {
                           sender ! response
                           self.become("waitNotification", state: self.waitNotification(), discardOld: true)
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
    }
    func waitNotification() -> Receive {
        return { [unowned self] (msg: Message) in
                   self.become("idle", state: self.idle(), discardOld: true)
                   #if DEBUG
                   print("\(Container.self).\(#function): recv \(msg) from \(msg.sender)")
                   #endif
               }
    }
}


class Monitor: Actor {
    var latencyRecord = [(Int, Double)]()
    override func receive(_ m: Actor.Message) {
        switch (m) {
        case let msg as RecordResult:
            latencyRecord.append((msg.client, msg.latency))
        case is ShowResult:
            var sum: Double = 0
            var min: Double = 10000000
            var max: Double = 0
            if latencyRecord.count != 0 {
                for r in latencyRecord {
                    //print("\(r.0) \(r.1)")
                    sum += r.1
                    min = r.1 < min ? r.1 : min
                    max = r.1 > max ? r.1 : max
                }

                print(String(format: "%10.1f %10.1f %10.1f", min, sum/Double(latencyRecord.count), max))
            }
        default:
            print("unexpected message \(m)")
        }
    }
}



func main() {
    if CommandLine.argc != 2 {
        print("\(CommandLine.arguments[0]) number")
        exit(1)
    }
    let count = Int(CommandLine.arguments[1])
    if count == nil {
        exit(2)
    }
    let system = ActorSystem(name: systemName)
    let _ = system.actorOf(Server.init, name: serverName)
    let monitor = system.actorOf(Monitor.init, name: monitorName)
    for i in 0..<count! {
        let client = system.actorOf(Client.init, name: "Client\(i)")
        let timestamp = timeval(tv_sec: 0, tv_usec:0)
        client ! Request(client: i, server: 0, timestamp: timestamp)
        usleep(1000)
    }
    sleep(10)
    monitor ! ShowResult(sender: nil)
    system.stop()
    exit(0)
}
// main()
