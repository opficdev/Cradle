//
//  DependencyGraphMacroDiagnosticsTests.swift
//  CradleMacrosTests
//
//  Created by opfic on 8/29/26.
//

import SwiftSyntaxMacrosTestSupport
import Testing

// struct graph 거부 확인
@Test
func dependencyGraphRejectsStruct() {
	assertMacroExpansion(
		"""
		@DependencyGraph
		struct Graph {}
		""",
		expandedSource: """
		struct Graph {}
		""",
		diagnostics: [
			DiagnosticSpec(
				message: "`@DependencyGraph`는 비 generic `final class` 또는 비 generic `actor`에만 적용할 수 있습니다.",
				line: 1,
				column: 1
			)
		],
		macros: testMacros
	)
}

// non-final class graph 거부 확인
@Test
func dependencyGraphRejectsNonFinalClass() {
	assertMacroExpansion(
		"""
		@DependencyGraph
		class Graph {}
		""",
		expandedSource: """
		class Graph {}
		""",
		diagnostics: [
			DiagnosticSpec(
				message: "`@DependencyGraph`는 비 generic `final class` 또는 비 generic `actor`에만 적용할 수 있습니다.",
				line: 1,
				column: 1
			)
		],
		macros: testMacros
	)
}

// generic class graph 거부 확인
@Test
func dependencyGraphRejectsGenericClass() {
	assertMacroExpansion(
		"""
		@DependencyGraph
		final class Graph<Value> {}
		""",
		expandedSource: """
		final class Graph<Value> {}
		""",
		diagnostics: [
			DiagnosticSpec(
				message: "`@DependencyGraph`는 비 generic `final class` 또는 비 generic `actor`에만 적용할 수 있습니다.",
				line: 1,
				column: 1
			)
		],
		macros: testMacros
	)
}

// generic actor graph 거부 확인
@Test
func dependencyGraphRejectsGenericActor() {
	assertMacroExpansion(
		"""
		@DependencyGraph
		actor Graph<Value> {}
		""",
		expandedSource: """
		actor Graph<Value> {}
		""",
		diagnostics: [
			DiagnosticSpec(
				message: "`@DependencyGraph`는 비 generic `final class` 또는 비 generic `actor`에만 적용할 수 있습니다.",
				line: 1,
				column: 1
			)
		],
		macros: testMacros
	)
}

// extension graph 거부 확인
@Test
func dependencyGraphRejectsExtension() {
	assertMacroExpansion(
		"""
		@DependencyGraph
		extension Graph {}
		""",
		expandedSource: """
		extension Graph {}
		""",
		diagnostics: [
			DiagnosticSpec(
				message: "`@DependencyGraph`는 비 generic `final class` 또는 비 generic `actor`에만 적용할 수 있습니다.",
				line: 1,
				column: 1
			)
		],
		macros: testMacros
	)
}

// graph 본체 밖 provider 거부 확인
@Test
func provideRejectsDeclarationOutsideGraphBody() {
	assertMacroExpansion(
		"""
		@Provide(.transient)
		private func makeService() -> Service { Service() }
		""",
		expandedSource: """
		private func makeService() -> Service { Service() }
		""",
		diagnostics: [
			DiagnosticSpec(
				message: "`@Provide`는 `@DependencyGraph` 본체에 직접 선언해야 합니다.",
				line: 1,
				column: 1
			)
		],
		macros: testMacros
	)
}

// private 아닌 provider 거부 확인
@Test
func dependencyGraphRejectsNonPrivateProvider() {
	assertMacroExpansion(
		"""
		@DependencyGraph
		final class Graph {
			@Provide(.transient)
			func makeService() -> Service { Service() }
		}
		""",
		expandedSource: """
		final class Graph {
			func makeService() -> Service { Service() }
		}
		""",
		diagnostics: [
			DiagnosticSpec(
				message: "`@Provide` factory는 private instance method여야 합니다.",
				line: 3,
				column: 2
			)
		],
		macros: testMacros
	)
}

// effect specifier provider 거부 확인
@Test
func dependencyGraphRejectsProviderEffect() {
	assertMacroExpansion(
		"""
		@DependencyGraph
		final class Graph {
			@Provide(.transient)
			private func makeService() async throws -> Service { Service() }
		}
		""",
		expandedSource: """
		final class Graph {
			private func makeService() async throws -> Service { Service() }
		}
		""",
		diagnostics: [
			DiagnosticSpec(
				message: "`@Provide` factory는 generic, type method, `async`, `throws`, `rethrows`를 가질 수 없습니다.",
				line: 3,
				column: 2
			)
		],
		macros: testMacros
	)
}

// generic type member provider 거부 확인
@Test
func dependencyGraphRejectsGenericTypeMemberProvider() {
	assertMacroExpansion(
		"""
		@DependencyGraph
		final class Graph {
			@Provide(.transient)
			private static func makeService<Value>() -> Service { Service() }
		}
		""",
		expandedSource: """
		final class Graph {
			private static func makeService<Value>() -> Service { Service() }
		}
		""",
		diagnostics: [
			DiagnosticSpec(
				message: "`@Provide` factory는 generic, type method, `async`, `throws`, `rethrows`를 가질 수 없습니다.",
				line: 3,
				column: 2
			)
		],
		macros: testMacros
	)
}

// 명시적 반환 타입 없는 provider 거부 확인
@Test
func dependencyGraphRejectsProviderWithoutReturnType() {
	assertMacroExpansion(
		"""
		@DependencyGraph
		final class Graph {
			@Provide(.transient)
			private func makeService() { Service() }
		}
		""",
		expandedSource: """
		final class Graph {
			private func makeService() { Service() }
		}
		""",
		diagnostics: [
			DiagnosticSpec(
				message: "`@Provide` factory는 명시적 반환 타입이 필요합니다.",
				line: 3,
				column: 2
			)
		],
		macros: testMacros
	)
}

// generic specialization 반환 타입 보존 확인
@Test
func dependencyGraphPreservesGenericSpecializationReturnType() {
	assertMacroExpansion(
		"""
		@DependencyGraph
		final class Graph {
			@Provide(.transient)
			private func makeService() -> Service<Value> { Service<Value>() }
		}
		""",
		expandedSource: """
		final class Graph {
			private func makeService() -> Service<Value> { Service<Value>() }

		    internal var service: Service<Value> {
		        makeService()
		    }
		}
		""",
		macros: testMacros
	)
}

// 같은 접근자 이름 provider 거부 확인
@Test
func dependencyGraphRejectsDuplicateAccessorName() {
	assertMacroExpansion(
		"""
		@DependencyGraph
		final class Graph {
			@Provide(.transient)
			private func makeFirst() -> Service { Service() }
			@Provide(.transient)
			private func makeSecond() -> Feature.Service { Feature.Service() }
		}
		""",
		expandedSource: """
		final class Graph {
			private func makeFirst() -> Service { Service() }
			private func makeSecond() -> Feature.Service { Feature.Service() }
		}
		""",
		diagnostics: [
			DiagnosticSpec(
				id: .init(domain: "Cradle", id: "duplicateAccessor"),
				message: "`service` 생성 프로퍼티를 만드는 등록이 중복됩니다.",
				line: 4,
				column: 30,
				highlights: ["Service"],
				notes: [
					NoteSpec(message: "`makeFirst` Factory의 등록입니다. 등록 타입은 `Service`입니다.", line: 3, column: 2),
					NoteSpec(message: "`makeSecond` Factory의 등록입니다. 등록 타입은 `Feature.Service`입니다.", line: 5, column: 2)
				]
			)
		],
		macros: testMacros
	)
}

// 기존 instance member 충돌 거부 확인
@Test
func dependencyGraphRejectsExistingMemberName() {
	assertMacroExpansion(
		"""
		@DependencyGraph
		final class Graph {
			func service() -> Service { Service() }
			@Provide(.transient)
			private func makeService() -> Service { Service() }
		}
		""",
		expandedSource: """
		final class Graph {
			func service() -> Service { Service() }
			private func makeService() -> Service { Service() }
		}
		""",
		diagnostics: [
			DiagnosticSpec(
				message: "생성 프로퍼티 이름이 기존 인스턴스 멤버와 충돌합니다.",
				line: 4,
				column: 2
			)
		],
		macros: testMacros
	)
}
// method 아닌 provider가 모든 생성 접근자를 중단하는지 확인
@Test
func dependencyGraphStopsAccessorsForNonMethodProvider() {
	assertMacroExpansion(
		"""
		@DependencyGraph
		final class Graph {
			@Provide(.transient)
			private var invalidService: Service { Service() }
			@Provide(.transient)
			private func makeValidService() -> ValidService { ValidService() }
		}
		""",
		expandedSource: """
		final class Graph {
			private var invalidService: Service { Service() }
			private func makeValidService() -> ValidService { ValidService() }
		}
		""",
		diagnostics: [
			DiagnosticSpec(
				message: "`@Provide` factory는 private instance method여야 합니다.",
				line: 3,
				column: 2
			)
		],
		macros: testMacros
	)
}
// 예약어 생성 접근자 이름 거부 확인
@Test
func dependencyGraphRejectsReservedAccessorName() {
	assertMacroExpansion(
		"""
		@DependencyGraph
		final class Graph {
			@Provide(.transient)
			private func makeClass() -> Class { Class() }
		}
		""",
		expandedSource: """
		final class Graph {
			private func makeClass() -> Class { Class() }
		}
		""",
		diagnostics: [
			DiagnosticSpec(
				message: "`@Provide` 등록 타입에서 유효한 프로퍼티 이름을 만들 수 없습니다.",
				line: 3,
				column: 2
			)
		],
		macros: testMacros
	)
}
