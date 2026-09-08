import Cradle
import Domain
import Infra

public struct LiveRepository: Repository { public init(service: any Service) {} }
public struct RepositoryInput {
	public let service: any Service
	public init(service: any Service) { self.service = service }
}
@DependencyGraph(input: RepositoryInput.self)
public final class RepositoryGraph {
	public init(input: RepositoryInput) {}
	@Provide public func makeRepository() -> any Repository { LiveRepository(service: input.service) }
}
