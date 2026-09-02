import Cradle

// public 생성 접근자에 노출하면 안 되는 internal service
struct InternalService {}

// access-control compiler 오류 검증용 graph
@DependencyGraph
public final class PublicGraph {
	// fixture graph 생성 허용 initializer
	public init() {}

	// internal 반환 타입 factory
	@Provide(.transient)
	private func makeInternalService() -> InternalService {
		InternalService()
	}
}
