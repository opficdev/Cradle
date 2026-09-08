import Cradle

public protocol Service {}
public struct LiveService: Service { public init() {} }
@DependencyGraph
public final class ServiceGraph {
	public init() {}
	@Provide public func makeService() -> any Service { LiveService() }
}
