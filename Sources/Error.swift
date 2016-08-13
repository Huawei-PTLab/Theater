/**
	Errors that could happen in the ActorSystem
*/
enum InternalError: Error {
	case invalidActorPath(pathString: String)
	case noSuchChild(pathString: String)
	case nullActorRef
}

public enum TheaterError: Error {
	case unexpectedMessage(msg: Actor.Message)
}
