//
//  ExternalProviderDiagnosticTests.swift
//  CradleMacrosTests
//
//  Created by opfic on 9/4/26.
//

import SwiftSyntaxMacrosTestSupport
import Testing
@testable import CradleMacros

// 보조 설명 진단의 고정 식별자 확인
@Test
func externalProviderDiagnosticKeepsNoteIdentifiersStable() {
	#expect(
		ExternalProviderLifetimeNote(factoryName: "makeService").noteID
			== .init(domain: "Cradle", id: "externalProviderLifetime")
	)
	#expect(
		ExternalResultProviderNote(factoryName: "makeService").noteID
			== .init(domain: "Cradle", id: "externalResultProvider")
	)
	#expect(
		ExternalMethodNameCollisionMemberNote(member: "member").noteID
			== .init(domain: "Cradle", id: "externalMethodNameCollisionMember")
	)
}

// 명시적 transient가 아닌 외부 입력 Factory의 오류와 수명 위치 확인
@Test(arguments: ["@Provide", "@Provide(.shared)"])
func externalProviderDiagnosticRejectsNonTransientLifetime(attribute: String) {
	assertMacroExpansion(
		"""
		@DependencyGraph
		final class Graph {
			\(attribute)
			private func `makeService`(@External id: Int) -> Service { Service() }
		}
		""",
		expandedSource: """
		final class Graph {
			private func `makeService`(@External id: Int) -> Service { Service() }
		}
		""",
		diagnostics: [
			DiagnosticSpec(
				id: .init(domain: "Cradle", id: "externalRequiresTransient"),
				message: "`@External`은 명시적인 `@Provide(.transient)`에서만 사용할 수 있습니다.",
				line: 4,
				column: 29,
				highlights: ["@External"],
				notes: [
					NoteSpec(
						message: "`makeService` Factory에 `.transient` 수명을 명시해야 합니다.",
						line: 3,
						column: 2
					)
				]
			)
		],
		macros: testMacros
	)
}

// 지원하지 않는 외부 입력 매개변수 형식의 원본 위치 확인
@Test(arguments: [
	"id: Int = 0",
	"id: Int...",
	"id: inout Int",
	"_ _: Int",
	"id: some Service",
	"id: @autoclosure () -> Int"
])
func externalProviderDiagnosticRejectsUnsupportedParameter(parameter: String) {
	assertMacroExpansion(
		"""
		@DependencyGraph
		final class Graph {
			@Provide(.transient)
			private func makeService(@External \(parameter)) -> Service { Service() }
		}
		""",
		expandedSource: """
		final class Graph {
			private func makeService(@External \(parameter)) -> Service { Service() }
		}
		""",
		diagnostics: [
			DiagnosticSpec(
				id: .init(domain: "Cradle", id: "invalidExternalParameter"),
				message: "`@External` 매개변수는 지원하는 형식이어야 합니다.",
				line: 4,
				column: 27,
				highlights: ["@External \(parameter)"]
			)
		],
		macros: testMacros
	)
}

// 외부 입력과 함께 선언한 다른 매개변수 attribute 거부 확인
@Test
func externalProviderDiagnosticRejectsAdditionalParameterAttribute() {
	assertMacroExpansion(
		"""
		@DependencyGraph
		final class Graph {
			@Provide(.transient)
			private func makeService(@External @OtherWrapper id: Int) -> Service { Service() }
		}
		""",
		expandedSource: """
		final class Graph {
			private func makeService(@External @OtherWrapper id: Int) -> Service { Service() }
		}
		""",
		diagnostics: [
			DiagnosticSpec(
				id: .init(domain: "Cradle", id: "invalidExternalParameter"),
				message: "`@External` 매개변수는 지원하는 형식이어야 합니다.",
				line: 4,
				column: 27,
				highlights: ["@External @OtherWrapper id: Int"]
			)
		],
		macros: testMacros
	)
}

// 직접 작성한 Optional 외부 입력에 기존 타입 진단을 유지하는지 확인
@Test(arguments: ["Int?", "Optional<Int>", "Swift.Optional<Int>"])
func externalProviderDiagnosticRejectsOptionalParameter(type: String) {
	assertMacroExpansion(
		"""
		@DependencyGraph
		final class Graph {
			@Provide(.transient)
			private func makeService(@External id: \(type)) -> Service { Service() }
		}
		""",
		expandedSource: """
		final class Graph {
			private func makeService(@External id: \(type)) -> Service { Service() }
		}
		""",
		diagnostics: [
			DiagnosticSpec(
				id: .init(domain: "Cradle", id: "invalidProviderType"),
				message: "`@Provide`의 반환 타입과 매개변수 타입에는 Optional을 사용할 수 없습니다.",
				line: 4,
				column: 41,
				highlights: [type]
			)
		],
		macros: testMacros
	)
}

// 외부 입력 결과를 일반 graph 의존성으로 연결하지 않는지 확인
@Test
func externalProviderDiagnosticRejectsExternalResultDependency() {
	assertMacroExpansion(
		"""
		@DependencyGraph
		final class Graph {
			@Provide(.transient)
			private func `makeProfile`(@External id: Int) -> Profile { Profile() }
			@Provide(.transient)
			private func makeScreen(profile: Profile) -> Screen { Screen() }
		}
		""",
		expandedSource: """
		final class Graph {
			private func `makeProfile`(@External id: Int) -> Profile { Profile() }
			private func makeScreen(profile: Profile) -> Screen { Screen() }
		}
		""",
		diagnostics: [
			DiagnosticSpec(
				id: .init(domain: "Cradle", id: "externalResultDependency"),
				message: "`Profile`은 `@External` 입력이 필요한 생성 결과이므로 graph 의존성으로 자동 연결할 수 없습니다.",
				line: 6,
				column: 35,
				highlights: ["Profile"],
				notes: [
					NoteSpec(
						message: "`makeProfile` Factory는 외부 입력과 함께 호출해야 합니다.",
						line: 3,
						column: 2
					)
				]
			)
		],
		macros: testMacros
	)
}

// 외부 입력과 함께 선언한 일반 의존성의 누락 등록 진단 확인
@Test
func externalProviderDiagnosticDoesNotInferMissingRegistration() {
	assertMacroExpansion(
		"""
		@DependencyGraph
		final class Graph {
			@Provide(.transient)
			private func makeProfile(
				repository: Repository,
				@External id: Int
			) -> Profile { Profile() }
		}
		""",
		expandedSource: """
		final class Graph {
			private func makeProfile(
				repository: Repository,
				@External id: Int
			) -> Profile { Profile() }
		}
		""",
		diagnostics: [
			DiagnosticSpec(
				id: .init(domain: "Cradle", id: "missingRegistration"),
				message: "`makeProfile`의 매개변수 타입 `Repository`에 대응하는 등록이 없습니다.",
				line: 5,
				column: 15,
				highlights: ["Repository"],
				notes: [
					NoteSpec(
						message: "`makeProfile` Factory가 이 의존성을 요구합니다.",
						line: 3,
						column: 2
					)
				]
			)
		],
		macros: testMacros
	)
}

// 기존 인스턴스 메서드와 외부 입력 생성 메서드의 이름 충돌 확인
@Test
func externalProviderDiagnosticRejectsExistingMethodName() {
	assertMacroExpansion(
		"""
		@DependencyGraph
		final class Graph {
			func profile(id: Int) -> Profile { Profile() }
			@Provide(.transient)
			private func makeProfile(@External id: Int) -> Profile { Profile() }
		}
		""",
		expandedSource: """
		final class Graph {
			func profile(id: Int) -> Profile { Profile() }
			private func makeProfile(@External id: Int) -> Profile { Profile() }
		}
		""",
		diagnostics: [
			DiagnosticSpec(
				id: .init(domain: "Cradle", id: "externalMethodNameCollision"),
				message: "`profile` 생성 메서드 이름이 기존 graph 멤버와 충돌합니다.",
				line: 5,
				column: 49,
				highlights: ["Profile"],
				notes: [
					NoteSpec(
						message: "`profile` 인스턴스 멤버가 같은 이름을 사용합니다.",
						line: 3,
						column: 2
					)
				]
			)
		],
		macros: testMacros
	)
}

// 기존 인스턴스 프로퍼티와 외부 입력 생성 메서드의 이름 충돌 확인
@Test
func externalProviderDiagnosticRejectsExistingPropertyName() {
	assertMacroExpansion(
		"""
		@DependencyGraph
		final class Graph {
			let profile = Profile()
			@Provide(.transient)
			private func makeProfile(@External id: Int) -> Profile { Profile() }
		}
		""",
		expandedSource: """
		final class Graph {
			let profile = Profile()
			private func makeProfile(@External id: Int) -> Profile { Profile() }
		}
		""",
		diagnostics: [
			DiagnosticSpec(
				id: .init(domain: "Cradle", id: "externalMethodNameCollision"),
				message: "`profile` 생성 메서드 이름이 기존 graph 멤버와 충돌합니다.",
				line: 5,
				column: 49,
				highlights: ["Profile"],
				notes: [
					NoteSpec(
						message: "`profile` 인스턴스 멤버가 같은 이름을 사용합니다.",
						line: 3,
						column: 2
					)
				]
			)
		],
		macros: testMacros
	)
}

// 일반 생성 프로퍼티와 외부 입력 생성 메서드의 이름 충돌 확인
@Test
func externalProviderDiagnosticRejectsGeneratedMemberName() {
	assertMacroExpansion(
		"""
		@DependencyGraph
		final class Graph {
			@Provide(.transient)
			private func makeProfile(@External id: Int) -> Profile { Profile() }
			@Provide(.transient)
			private func `makeOtherProfile`() -> Profile { Profile() }
		}
		""",
		expandedSource: """
		final class Graph {
			private func makeProfile(@External id: Int) -> Profile { Profile() }
			private func `makeOtherProfile`() -> Profile { Profile() }
		}
		""",
		diagnostics: [
			DiagnosticSpec(
				id: .init(domain: "Cradle", id: "externalMethodNameCollision"),
				message: "`profile` 생성 메서드 이름이 기존 graph 멤버와 충돌합니다.",
				line: 4,
				column: 49,
				highlights: ["Profile"],
				notes: [
					NoteSpec(
						message: "`makeOtherProfile` Factory가 `profile` 생성 멤버를 만듭니다.",
						line: 5,
						column: 2
					)
				]
			)
		],
		macros: testMacros
	)
}

// source 저장 프로퍼티와 외부 입력 생성 메서드의 이름 충돌 확인
@Test
func externalProviderDiagnosticRejectsSourceMemberName() {
	assertMacroExpansion(
		"""
		@DependencyGraph
		final class Profile {}
		@DependencyGraph(sources: [Profile.self])
		final class Graph {
			@Provide(.transient)
			private func makeProfile(@External id: Int) -> Profile { Profile() }
		}
		""",
		expandedSource: """
		final class Profile {}
		final class Graph {
			private func makeProfile(@External id: Int) -> Profile { Profile() }
		}
		""",
		diagnostics: [
			DiagnosticSpec(
				id: .init(domain: "Cradle", id: "externalMethodNameCollision"),
				message: "`profile` 생성 메서드 이름이 기존 graph 멤버와 충돌합니다.",
				line: 6,
				column: 49,
				highlights: ["Profile"],
				notes: [
					NoteSpec(
						message: "`Profile` source graph가 `profile` 저장 프로퍼티를 만듭니다.",
						line: 2,
						column: 28
					)
				]
			)
		],
		macros: testMacros
	)
}
