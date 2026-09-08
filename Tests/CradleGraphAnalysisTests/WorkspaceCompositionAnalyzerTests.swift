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

// 동명 일반 함수보다 수집한 @Provide Factory의 input 읽기를 우선하는지 검증
@Test
func workspaceCompositionAnalyzerUsesExactProviderDeclaration() {
	let target = WorkspaceTargetDescriptor(
		id: WorkspaceTargetID("App"), moduleName: "App", dependencyIDs: []
	)
	let collector = WorkspaceDeclarationCollector(targets: [target])
	collector.collect(sourceFile: Parser.parse(source: """
	struct Input {
		let primary: Service
		let backup: Service
	}
	class Worker {}
	final class PrimaryWorker: Worker {}
	final class BackupWorker: Worker {}
	final class Container {
		let worker: Worker
		let service: Service
		init(worker: Worker, service: Service) {
			self.worker = worker
			self.service = service
		}
	}
	@DependencyGraph(input: Input.self) final class Entry {
		private func make(_ ignored: Int) -> Container {
			Container(worker: BackupWorker(), service: input.backup)
		}
		@Provide private func make() -> Container {
			Container(worker: PrimaryWorker(), service: input.primary)
		}
	}
	"""), context: compositionContext(targetID: "App", moduleName: "App", path: "App.swift"))

	let model = WorkspaceCompositionAnalyzer(
		index: collector.index(),
		roots: [WorkspaceDeclarationID(targetID: WorkspaceTargetID("App"), lexicalPath: ["Entry"])],
		compositionTypes: [
			WorkspaceDeclarationID(targetID: WorkspaceTargetID("App"), lexicalPath: ["Container"]),
			WorkspaceDeclarationID(targetID: WorkspaceTargetID("App"), lexicalPath: ["PrimaryWorker"]),
			WorkspaceDeclarationID(targetID: WorkspaceTargetID("App"), lexicalPath: ["BackupWorker"])
		]
	).analyze()

	#expect(model.nodes.contains { $0.kind == .input && $0.label == "input.primary" })
	#expect(!model.nodes.contains { $0.kind == .input && $0.label == "input.backup" })
	#expect(model.nodes.contains { $0.label == "App.PrimaryWorker" })
	#expect(!model.nodes.contains { $0.label == "App.BackupWorker" })
}

// guard binding이 가린 input과 명시적인 self.input 참조를 구분하는지 검증
@Test
func workspaceCompositionAnalyzerHonorsGuardInputShadowing() throws {
	let target = WorkspaceTargetDescriptor(
		id: WorkspaceTargetID("App"), moduleName: "App", dependencyIDs: []
	)
	let collector = WorkspaceDeclarationCollector(targets: [target])
	collector.collect(sourceFile: Parser.parse(source: """
	struct Input { let service: Service }
	final class Feature { init(service: Service) {} }
	@DependencyGraph(input: Input.self) final class Entry {
		@Provide func makeShadowed() -> Feature {
			guard let input = localInput() else { return Feature(service: Service()) }
			return Feature(service: input.service)
		}
		@Provide func makeExplicit() -> Feature {
			guard let input = localInput() else { return Feature(service: Service()) }
			return Feature(service: self.input.service)
		}
	}
	"""), context: compositionContext(targetID: "App", moduleName: "App", path: "App.swift"))

	let model = WorkspaceCompositionAnalyzer(
		index: collector.index(),
		roots: [WorkspaceDeclarationID(targetID: WorkspaceTargetID("App"), lexicalPath: ["Entry"])],
		compositionTypes: []
	).analyze()
	let input = try #require(model.nodes.first { $0.kind == .input && $0.label == "input.service" })
	let readSources = model.edges.filter { $0.kind == .inputRead && $0.destination == input.key }.map(\.from)

	#expect(readSources.count == 1)
	#expect(model.nodes.first { $0.key == readSources[0] }?.label.contains("makeExplicit") == true)
	#expect(model.diagnostics.contains { $0.code == .unsupportedControlFlow })
}

// composition fixture source context 생성
private func compositionContext(targetID: String, moduleName: String, path: String, dependencies: Set<String> = [], imports: Set<String> = []) -> WorkspaceSourceContext {
	WorkspaceSourceContext(targetID: WorkspaceTargetID(targetID), moduleName: moduleName, path: path, dependencyIDs: Set(dependencies.map(WorkspaceTargetID.init)), importedModules: imports)
}

// swiftlint:enable line_length
