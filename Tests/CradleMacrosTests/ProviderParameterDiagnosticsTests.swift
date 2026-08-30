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
				message: "`@Provide` factory 매개변수는 지원 형식이어야 하며 지역 이름이 "
					+ "등록 생성 접근자와 일치해야 합니다.",
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
				message: "`@Provide` factory 매개변수는 지원 형식이어야 하며 지역 이름이 "
					+ "등록 생성 접근자와 일치해야 합니다.",
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
				message: "`makeService`의 매개변수 `dependency`에 대응하는 등록이 없습니다.",
				line: 5,
				column: 27,
				highlights: ["dependency"],
				notes: [NoteSpec(message: "`makeService` Factory가 이 의존성을 요구합니다.", line: 4, column: 2)]
			)
		],
		macros: testMacros
	)
}

// 같은 타입이어도 지역 이름의 대소문자가 다르면 연결하지 않는지 확인
@Test
func providerParameterDiagnosticsRequireExactAccessorName() {
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
		}
		""",
		diagnostics: [
			DiagnosticSpec(
				id: .init(domain: "Cradle", id: "missingRegistration"),
				message: "`makeClient`의 매개변수 `urlsession`에 대응하는 등록이 없습니다.",
				line: 4,
				column: 26,
				highlights: ["urlsession"],
				notes: [NoteSpec(message: "`makeClient` Factory가 이 의존성을 요구합니다.", line: 3, column: 2)]
			)
		],
		macros: testMacros
	)
}
