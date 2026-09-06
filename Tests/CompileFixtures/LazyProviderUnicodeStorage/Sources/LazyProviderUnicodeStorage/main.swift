// swiftlint:disable type_name
import Cradle

final class Service🐱 {}
final class Service🐶 {}

// 정규화하면 같은 철자가 되는 반환 타입을 함께 보관할 lazy graph
@DependencyGraph
final class LazyProviderUnicodeStorageGraph {
	@Provide(.lazy)
	private func makeService🐱() -> Service🐱 {
		Service🐱()
	}

	@Provide(.lazy)
	private func makeService🐶() -> Service🐶 {
		Service🐶()
	}
}

let graph = LazyProviderUnicodeStorageGraph()
_ = graph.service🐱
_ = graph.service🐶
// swiftlint:enable type_name
