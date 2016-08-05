/**
	Errors that could happen in the ActorSystem
*/
enum InternalError: ErrorProtocol {
	case invalidActorPath(pathString: String)
	case noSuchChild(pathString: String)
}
