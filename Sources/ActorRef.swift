import Foundation
/**
	An actor system has a tree like structure, ActorPath gives you an url like
	way to find an actor inside a given actor system.

	For now ActorPath only stores a String path. In the future this class can
	be extended to store network path, communication protocol, etc. 
*/
public class ActorPath {
    
    public let asString : String
    
    public init(path : String) {
        self.asString = path
    }
}

/**
	'ActorRef' provides a reference to a given 'Actor', you should always talk
	to actors though it's ActorRef.
*/
public class ActorRef: CustomStringConvertible {
    
	/**
		For debugging
	*/
	public var description: String {
		get {
			return "<\(self.dynamicType): \(path.asString)>"
		}
	}
    
	internal let context: ActorSystem

	internal var supervisor: ActorRef?

	internal var children: [String : ActorRef] = [String : ActorRef]()

    /**
		 The Path to this ActorRef
     */
    public let path : ActorPath

	/**
		Reference to the actual actor.
		This is optional because actual actor instance might crash (e.g. in the remote node)
	 */
	internal var actorInstance: Actor?

	/**
		A backup of the actual actor instance, in case actor crashes.

		TODO: refresh backup occasionally 
	*/
	// private var backup: Actor 
    
	/**
		Called by Actor.actorOf
	*/
    internal init(path : ActorPath, actorInstance: Actor, context: ActorSystem, supervisor: ActorRef) {
        self.path = path
		self.actorInstance = actorInstance
		self.context = context
		self.supervisor = supervisor
		// self.backup = actorInstance.copy() as! Actor 	// TODO: check the usage of copy()
    }

	/**
		Called by ActorSystem to create root supervisor.
	*/
    internal init(path : ActorPath, actorInstance: Actor, context: ActorSystem) {
        self.path = path
		self.actorInstance = actorInstance
		self.context = context
		self.supervisor = nil
    }
    
    /**
		This method is used to send a message to the underlying Actor.
     
		- parameter msg : The message to send to the Actor.
    */
    public func tell (_ msg : Unmanaged<Actor.Message>) -> Void {
		if let actor = self.actorInstance {
			actor.tell(msg)
		} else {
			print("[WARNING] Fail to deliver message \(msg) to \(self)")
		}
    }
    
	internal func stop(_ ref: ActorRef) {
		actorInstance?.stop(ref)
	}
}
