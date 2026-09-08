import Cradle
import Data
import Domain
import Infra

public final class InfraGraphSet {
	public let serviceGraph = ServiceGraph()
	public init() {}
}
public final class DevelopmentGraphSet {
	// 생성된 source graph의 기존 instance 보관
	public let serviceGraph: ServiceGraph
	public let repositoryGraph: RepositoryGraph
	public let useCaseGraph: UseCaseGraph
	public init(infra: InfraGraphSet) {
		self.serviceGraph = infra.serviceGraph
		self.repositoryGraph = RepositoryGraph(input: RepositoryInput(service: infra.serviceGraph.service))
		self.useCaseGraph = UseCaseGraph(input: UseCaseInput(repository: repositoryGraph.repository))
	}
}
@DependencyGraph
public final class AppGraph {
	public init() {}
	@Provide private func makeInfra() -> InfraGraphSet { InfraGraphSet() }
	@Provide private func makeDevelopment(infra: InfraGraphSet) -> DevelopmentGraphSet {
		DevelopmentGraphSet(infra: infra)
	}
}
