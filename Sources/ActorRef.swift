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
    
	/**
		Supervisor is responsible for managing life cycle of this actor
	
		Conceptually, supervisor can be changed, hence we use `var`.
    */
	internal var supervisor: ActorRef

	internal var children: [String : ActorRef] = [String : ActorRef]()

    /**
		 The Path to this ActorRef
     */
    public let path : ActorPath

	/**
		Reference to the actual actor.
	 */
	internal var actorInstance: Actor

	/**
		A backup of the actual actor instance, in case actor crashes.

		TODO: refresh backup occasionally 
	*/
	// private var backup: Actor 
    
	/**
		Called only by Actor.actorOf
	*/
    internal init(path : ActorPath, actorInstance: Actor, supervisor: ActorRef) {
        self.path = path
		self.actorInstance = actorInstance
		// self.backup = actorInstance.copy() as! Actor 	// TODO: check the usage of copy()
		self.supervisor = supervisor
    }
    
    /**
		This method is used to send a message to the underlying Actor.
     
		- parameter msg : The message to send to the Actor.
    */
    public func tell (_ msg : Unmanaged<Actor.Message>) -> Void {
		self.actorInstance.tell(msg)
    }
    
	internal func stop(_ ref: ActorRef) {
		//TODO
	}
}
