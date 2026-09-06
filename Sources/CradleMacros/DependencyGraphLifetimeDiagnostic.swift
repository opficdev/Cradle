//
//  DependencyGraphLifetimeDiagnostic.swift
//  CradleMacros
//
//  Created by opfic on 9/6/26.
//

import SwiftDiagnostics

// graph 수명 선언과 static 접근점 오류
enum DependencyGraphLifetimeDiagnostic: DiagnosticMessage {
	// 지원하지 않는 lifetime 인자
	case invalidLifetime
	// 비격리 class의 checked Sendable 준수 누락
	case sharedGraphRequiresSendable
	// 비격리 class의 unchecked Sendable 우회
	case uncheckedSharedGraph
	// 생성 static member와 기존 type member 충돌
	case sharedMemberCollision

	// 고정 Macro diagnostic 식별자
	var diagnosticID: MessageID {
		switch self {
		case .invalidLifetime:
			MessageID(domain: "Cradle", id: "invalidDependencyGraphLifetime")
		case .sharedGraphRequiresSendable:
			MessageID(domain: "Cradle", id: "sharedGraphRequiresSendable")
		case .uncheckedSharedGraph:
			MessageID(domain: "Cradle", id: "uncheckedSharedGraph")
		case .sharedMemberCollision:
			MessageID(domain: "Cradle", id: "sharedGraphMemberCollision")
		}
	}

	// 소비자 선언의 수정 방향
	var message: String {
		switch self {
		case .invalidLifetime:
			"`@DependencyGraph`의 첫 위치 인자는 직접 작성한 `.instance` 또는 `.shared`여야 합니다."
		case .sharedGraphRequiresSendable:
			"비격리 `final class`에서 `.shared`를 사용하려면 선언에 checked `Sendable` 준수를 직접 작성해야 합니다."
		case .uncheckedSharedGraph:
			"비격리 `final class`의 `.shared`에는 `@unchecked Sendable`을 사용할 수 없습니다."
		case .sharedMemberCollision:
			"생성할 `shared` static member가 기존 type member와 충돌합니다."
		}
	}

	// 모든 lifetime 선언 오류의 컴파일 중단
	var severity: DiagnosticSeverity { .error }
}
