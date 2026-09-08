//
//  WorkspaceCompositionAnalyzerTests.swift
//  CradleGraphAnalysisTests
//
//  Created by opfic on 9/8/26.
//

import SwiftParser
import Testing
@testable import CradleGraphAnalysis

// 다중 module fixture 원본을 보존하기 위한 긴 입력 허용
// swiftlint:disable line_length

// AppGraph와 일반 GraphSet initializer를 거친 input provider 출처를 연결하는지 확인
@Test
// swiftlint:disable:next function_body_length
func workspaceCompositionAnalyzerConnectsGraphInputBindings() {
	let descriptors = [
		WorkspaceTargetDescriptor(id: WorkspaceTargetID("Infra"), moduleName: "Infra", dependencyIDs: []),
		WorkspaceTargetDescriptor(id: WorkspaceTargetID("Data"), moduleName: "Data", dependencyIDs: [WorkspaceTargetID("Infra")]),
		WorkspaceTargetDescriptor(id: WorkspaceTargetID("Domain"), moduleName: "Domain", dependencyIDs: [WorkspaceTargetID("Data")]),
		WorkspaceTargetDescriptor(id: WorkspaceTargetID("App"), moduleName: "App", dependencyIDs: [WorkspaceTargetID("Infra"), WorkspaceTargetID("Data"), WorkspaceTargetID("Domain")])
	]
	let collector = WorkspaceDeclarationCollector(targets: descriptors)
	collector.collect(sourceFile: Parser.parse(source: """
	@DependencyGraph final class ServiceGraph {
		@Provide func makeService() -> Service { Service() }
	}
	"""), context: compositionContext(targetID: "Infra", moduleName: "Infra", path: "Infra.swift"))
	collector.collect(sourceFile: Parser.parse(source: """
	import Infra
	struct RepositoryInput {
		let service: Service
		init(from provider: Service) { self.service = provider }
	}
	@DependencyGraph(input: RepositoryInput.self) final class RepositoryGraph {
		@Provide func makeRepository() -> Repository { Repository(service: input.service) }
	}
	"""), context: compositionContext(targetID: "Data", moduleName: "Data", path: "Data.swift", dependencies: ["Infra"], imports: ["Infra"]))
	collector.collect(sourceFile: Parser.parse(source: """
	import Data
	struct UseCaseInput { let repository: Repository }
	@DependencyGraph(input: UseCaseInput.self) final class UseCaseGraph {
		@Provide func makeUseCase() -> UseCase { UseCase(repository: input.repository) }
	}
	"""), context: compositionContext(targetID: "Domain", moduleName: "Domain", path: "Domain.swift", dependencies: ["Data"], imports: ["Data"]))
	collector.collect(sourceFile: Parser.parse(source: """
	import Infra
	import Data
	import Domain
	final class InfraGraphSet { let serviceGraph = ServiceGraph() }
	final class DevelopmentGraphSet {
		let repositoryGraph: RepositoryGraph
		let useCaseGraph: UseCaseGraph
		init(infra: InfraGraphSet) {
			self.repositoryGraph = RepositoryGraph(input: RepositoryInput(from: infra.serviceGraph.service))
			self.useCaseGraph = UseCaseGraph(input: UseCaseInput(repository: repositoryGraph.repository))
		}
	}
	@DependencyGraph final class AppGraph {
		@Provide func makeInfra() -> InfraGraphSet { InfraGraphSet() }
		@Provide func makeDevelopment(infra: InfraGraphSet) -> DevelopmentGraphSet { DevelopmentGraphSet(infra: infra) }
	}
	"""), context: compositionContext(targetID: "App", moduleName: "App", path: "App.swift", dependencies: ["Infra", "Data", "Domain"], imports: ["Infra", "Data", "Domain"]))

	let index = collector.index()
	let model = WorkspaceCompositionAnalyzer(
		index: index,
		roots: [WorkspaceDeclarationID(targetID: WorkspaceTargetID("App"), lexicalPath: ["AppGraph"])],
		compositionTypes: [
			WorkspaceDeclarationID(targetID: WorkspaceTargetID("App"), lexicalPath: ["InfraGraphSet"]),
			WorkspaceDeclarationID(targetID: WorkspaceTargetID("App"), lexicalPath: ["DevelopmentGraphSet"])
		]
	).analyze()
	let nodes = Dictionary(uniqueKeysWithValues: model.nodes.map { ($0.key, $0) })

	#expect(model.nodes.contains { $0.kind == .input && $0.label == "input.service" })
	#expect(model.nodes.contains { $0.kind == .input && $0.label == "input.repository" })
	#expect(model.edges.contains { $0.kind == .inputBinding && nodes[$0.from]?.label == "input.service" && nodes[$0.destination]?.label.contains("makeService") == true })
	#expect(model.edges.contains { $0.kind == .inputBinding && nodes[$0.from]?.label == "input.repository" && nodes[$0.destination]?.label.contains("makeRepository") == true })
}

// composition fixture source context 생성
private func compositionContext(targetID: String, moduleName: String, path: String, dependencies: Set<String> = [], imports: Set<String> = []) -> WorkspaceSourceContext {
	WorkspaceSourceContext(targetID: WorkspaceTargetID(targetID), moduleName: moduleName, path: path, dependencyIDs: Set(dependencies.map(WorkspaceTargetID.init)), importedModules: imports)
}

// swiftlint:enable line_length
