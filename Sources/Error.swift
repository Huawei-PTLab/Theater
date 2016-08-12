/**
	Errors that could happen in the ActorSystem
*/
enum InternalError: Error {
	case invalidActorPath(pathString: String)
	case noSuchChild(pathString: String)
	case NullActorRef
}
