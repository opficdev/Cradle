import Cradle
import Data
import Domain
import Infra

public final class InfraGraphSet {
	public let serviceGraph = ServiceGraph()
	public init() {}
}
public final class DevelopmentGraphSet {
	public let repositoryGraph: RepositoryGraph
	public let useCaseGraph: UseCaseGraph
	public init(infra: InfraGraphSet) {
		self.repositoryGraph = RepositoryGraph(input: RepositoryInput(service: infra.serviceGraph.service))
		self.useCaseGraph = UseCaseGraph(input: UseCaseInput(repository: repositoryGraph.repository))
	}
}
@DependencyGraph
public final class AppGraph {
	public init() {}
	@Provide public func makeInfra() -> InfraGraphSet { InfraGraphSet() }
	@Provide public func makeDevelopment(infra: InfraGraphSet) -> DevelopmentGraphSet { DevelopmentGraphSet(infra: infra) }
}
