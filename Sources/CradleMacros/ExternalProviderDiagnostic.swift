//
//  ExternalProviderDiagnostic.swift
//  CradleMacros
//
//  Created by opfic on 9/4/26.
//

import SwiftDiagnostics

// 외부 입력 Factory에 명시적 transient 수명을 요구하는 오류
struct ExternalRequiresTransientDiagnostic: DiagnosticMessage {
	// 외부 입력 수명 오류의 고정 식별자
	var diagnosticID: MessageID {
		MessageID(domain: "Cradle", id: "externalRequiresTransient")
	}

	// 외부 입력의 허용 수명 안내
	var message: String {
		"`@External`은 명시적인 `@Provide(.transient)`에서만 사용할 수 있습니다."
	}

	// 유효하지 않은 외부 입력 Factory의 컴파일 중단
	var severity: DiagnosticSeverity { .error }
}

// 외부 입력과 맞지 않는 Factory 수명 위치 안내
struct ExternalProviderLifetimeNote: NoteMessage {
	// 수명 오류가 발생한 Factory 이름
	let factoryName: String

	// Factory 수명 위치의 고정 식별자
	var noteID: MessageID {
		MessageID(domain: "Cradle", id: "externalProviderLifetime")
	}

	// 명시적 transient 수명 지정 안내
	var message: String {
		"\(quotedFactoryName(factoryName)) Factory에 `.transient` 수명을 명시해야 합니다."
	}
}

// 지원하지 않는 외부 입력 매개변수 형식 오류
struct InvalidExternalParameterDiagnostic: DiagnosticMessage {
	// 외부 입력 형식 오류의 고정 식별자
	var diagnosticID: MessageID {
		MessageID(domain: "Cradle", id: "invalidExternalParameter")
	}

	// 외부 입력 매개변수 형식 안내
	var message: String {
		"`@External` 매개변수는 지원하는 형식이어야 합니다."
	}

	// 유효하지 않은 외부 입력 선언의 컴파일 중단
	var severity: DiagnosticSeverity { .error }
}

// 외부 입력이 필요한 결과의 자동 graph 연결 오류
struct ExternalResultDependencyDiagnostic: DiagnosticMessage {
	// graph 의존성으로 요구한 외부 입력 결과 타입
	let type: String

	// 외부 결과 연결 오류의 고정 식별자
	var diagnosticID: MessageID {
		MessageID(domain: "Cradle", id: "externalResultDependency")
	}

	// 외부 입력 생성 메서드 직접 호출 안내
	var message: String {
		"`\(type)`은 `@External` 입력이 필요한 생성 결과이므로 graph 의존성으로 자동 연결할 수 없습니다."
	}

	// 잘못된 외부 결과 연결의 컴파일 중단
	var severity: DiagnosticSeverity { .error }
}

// 외부 입력 결과를 만드는 Factory 위치 안내
struct ExternalResultProviderNote: NoteMessage {
	// 외부 입력 결과 Factory 이름
	let factoryName: String

	// 외부 결과 Factory 위치의 고정 식별자
	var noteID: MessageID {
		MessageID(domain: "Cradle", id: "externalResultProvider")
	}

	// 외부 입력을 요구하는 Factory 설명
	var message: String {
		"\(quotedFactoryName(factoryName)) Factory는 외부 입력과 함께 호출해야 합니다."
	}
}

// 외부 입력 생성 메서드와 graph 멤버의 이름 충돌 오류
struct ExternalMethodNameCollisionDiagnostic: DiagnosticMessage {
	// 충돌한 생성 메서드 이름
	let name: String

	// 생성 메서드 이름 충돌의 고정 식별자
	var diagnosticID: MessageID {
		MessageID(domain: "Cradle", id: "externalMethodNameCollision")
	}

	// 충돌한 생성 메서드 이름 안내
	var message: String {
		"`\(name)` 생성 메서드 이름이 기존 graph 멤버와 충돌합니다."
	}

	// 이름이 충돌한 graph의 컴파일 중단
	var severity: DiagnosticSeverity { .error }
}

// 외부 입력 생성 메서드와 이름이 같은 선언 위치 안내
struct ExternalMethodNameCollisionMemberNote: NoteMessage {
	// 충돌한 선언 설명
	let member: String

	// 이름 충돌 선언 위치의 고정 식별자
	var noteID: MessageID {
		MessageID(domain: "Cradle", id: "externalMethodNameCollisionMember")
	}

	// 같은 이름을 사용하는 선언 안내
	var message: String { member }
}
