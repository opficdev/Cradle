//
//  ProviderParameterDiagnosticsTests.swift
//  CradleMacrosTests
//
//  Created by opfic on 8/30/26.
//

import SwiftSyntaxMacrosTestSupport
import Testing

// 지원하지 않는 provider 매개변수 형식 거부 확인
@Test(arguments: [
	"service: Service = Service()",
	"services: Service...",
	"service: inout Service",
	"_ _: Service",
	"service: some Service",
	"services: [some Service]",
	"service: @autoclosure () -> Service",
	"service: @autoclosure @escaping () -> Service"
])
func providerParameterDiagnosticsRejectUnsupportedSyntax(parameter: String) {
	assertMacroExpansion(
		"""
		@DependencyGraph
		final class Graph {
			@Provide
			private func makeService(\(parameter)) -> Service { Service() }
		}
		""",
		expandedSource: """
		final class Graph {
			private func makeService(\(parameter)) -> Service { Service() }
		}
		""",
		diagnostics: [
			DiagnosticSpec(
				message: "`@Provide` Factory 매개변수는 지원하는 형식이어야 합니다.",
				line: 3,
				column: 2
			)
		],
		macros: testMacros
	)
}

// 등록된 의존성이 있어도 백틱 autoclosure와 escaping 조합을 거부하는지 확인
@Test(arguments: [
	"@`autoclosure`",
	"@`autoclosure` @escaping",
	"@escaping @`autoclosure`",
	"@`autoclosure` @`escaping`"
])
func providerParameterDiagnosticsRejectEscapedAutoclosure(attributes: String) {
	assertMacroExpansion(
		"""
		@DependencyGraph
		final class Graph {
			@Provide
			private func makeFeature(service: \(attributes) () -> Service) -> Feature { Feature() }
			@Provide
			private func makeService() -> Service { Service() }
		}
		""",
		expandedSource: """
		final class Graph {
			private func makeFeature(service: \(attributes) () -> Service) -> Feature { Feature() }
			private func makeService() -> Service { Service() }
		}
		""",
		diagnostics: [
			DiagnosticSpec(
				message: "`@Provide` Factory 매개변수는 지원하는 형식이어야 합니다.",
				line: 3,
				column: 2
			)
		],
		macros: testMacros
	)
}

// 일반 graph member나 누락 이름으로 provider 연결을 대신하지 않는지 확인
@Test(arguments: [
	"// 등록 provider 없음",
	"func dependency() -> Dependency { Dependency() }",
	"var dependency: () -> Dependency { { Dependency() } }"
])
func providerParameterDiagnosticsRejectNonProviderConnection(member: String) {
	assertMacroExpansion(
		"""
		@DependencyGraph
		final class Graph {
			\(member)
			@Provide
			private func makeService(dependency: Dependency) -> Service { Service() }
			@Provide
			private func makeOther() -> Other { Other() }
		}
		""",
		expandedSource: """
		final class Graph {
			\(member)
			private func makeService(dependency: Dependency) -> Service { Service() }
			private func makeOther() -> Other { Other() }
		}
		""",
		diagnostics: [
			DiagnosticSpec(
				id: .init(domain: "Cradle", id: "missingRegistration"),
				message: "`makeService`의 매개변수 타입 `Dependency`에 대응하는 등록이 없습니다.",
				line: 5,
				column: 39,
				highlights: ["Dependency"],
				notes: [NoteSpec(message: "`makeService` Factory가 이 의존성을 요구합니다.", line: 4, column: 2)]
			)
		],
		macros: testMacros
	)
}

// 지역 이름과 관계없이 같은 타입을 연결하는지 확인
@Test
func providerParameterDiagnosticsConnectByType() {
	assertMacroExpansion(
		"""
		@DependencyGraph
		final class Graph {
			@Provide
			private func makeClient(urlsession: URLSession) -> Client { Client() }
			@Provide
			private func makeURLSession() -> URLSession { URLSession() }
		}
		""",
		expandedSource: """
		final class Graph {
			private func makeClient(urlsession: URLSession) -> Client { Client() }
			private func makeURLSession() -> URLSession { URLSession() }

		    internal var client: Client {
		        makeClient(urlsession: urlSession)
		    }

		    internal var urlSession: URLSession {
		        makeURLSession()
		    }
		}
		""",
		macros: testMacros
	)
}

// 제네릭 인자 철자가 다른 등록 타입을 연결하지 않는지 확인
@Test
func providerParameterDiagnosticsDistinguishesGenericArguments() {
	assertMacroExpansion(
		"""
		@DependencyGraph
		final class Graph {
			@Provide
			private func makeConsumer(box: Box<Int>) -> Consumer { Consumer() }
			@Provide
			private func makeBox() -> Box<String> { Box() }
		}
		""",
		expandedSource: """
		final class Graph {
			private func makeConsumer(box: Box<Int>) -> Consumer { Consumer() }
			private func makeBox() -> Box<String> { Box() }
		}
		""",
		diagnostics: [
			DiagnosticSpec(
				id: .init(domain: "Cradle", id: "missingRegistration"),
				message: "`makeConsumer`의 매개변수 타입 `Box<Int>`에 대응하는 등록이 없습니다.",
				line: 4,
				column: 33,
				highlights: ["Box<Int>"],
				notes: [NoteSpec(message: "`makeConsumer` Factory가 이 의존성을 요구합니다.", line: 3, column: 2)]
			)
		],
		macros: testMacros
	)
}
