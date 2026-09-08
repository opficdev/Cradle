import Cradle

public protocol Repository {}
public struct UseCase { public init(repository: any Repository) {} }
public struct UseCaseInput {
	public let repository: any Repository
	public init(repository: any Repository) { self.repository = repository }
}
@DependencyGraph(input: UseCaseInput.self)
public final class UseCaseGraph {
	public init(input: UseCaseInput) {}
	@Provide public func makeUseCase() -> UseCase { UseCase(repository: input.repository) }
}
