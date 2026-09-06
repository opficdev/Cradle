import Cradle

struct LazyProviderInvalidLeaf {}
struct LazyProviderInvalidBranch {}
struct LazyProviderInvalidCycleFirst {}
struct LazyProviderInvalidCycleSecond {}

// shared가 lazy 등록을 앞당기는 연결 거부 확인 graph
@DependencyGraph
final class SharedLazyProviderInvalidGraph {
	@Provide(.lazy)
	private func makeLazyProviderInvalidLeaf() -> LazyProviderInvalidLeaf {
		LazyProviderInvalidLeaf()
	}

	@Provide(.shared)
	private func makeLazyProviderInvalidBranch(
		leaf: LazyProviderInvalidLeaf
	) -> LazyProviderInvalidBranch {
		LazyProviderInvalidBranch()
	}
}

// lazy가 transient 결과를 보관하는 연결 거부 확인 graph
@DependencyGraph
final class LazyTransientProviderInvalidGraph {
	@Provide(.transient)
	private func makeLazyProviderInvalidLeaf() -> LazyProviderInvalidLeaf {
		LazyProviderInvalidLeaf()
	}

	@Provide(.lazy)
	private func makeLazyProviderInvalidBranch(
		leaf: LazyProviderInvalidLeaf
	) -> LazyProviderInvalidBranch {
		LazyProviderInvalidBranch()
	}
}

// 외부 입력과 lazy 수명의 조합 거부 확인 graph
@DependencyGraph
final class LazyExternalProviderInvalidGraph {
	@Provide(.lazy)
	private func makeLazyProviderInvalidBranch(
		@External value: Int
	) -> LazyProviderInvalidBranch {
		_ = value
		return LazyProviderInvalidBranch()
	}
}

// lazy 등록끼리 순환하는 연결 거부 확인 graph
@DependencyGraph
final class LazyProviderCycleInvalidGraph {
	@Provide(.lazy)
	private func makeLazyProviderInvalidCycleFirst(
		second: LazyProviderInvalidCycleSecond
	) -> LazyProviderInvalidCycleFirst {
		LazyProviderInvalidCycleFirst()
	}

	@Provide(.lazy)
	private func makeLazyProviderInvalidCycleSecond(
		first: LazyProviderInvalidCycleFirst
	) -> LazyProviderInvalidCycleSecond {
		LazyProviderInvalidCycleSecond()
	}
}
