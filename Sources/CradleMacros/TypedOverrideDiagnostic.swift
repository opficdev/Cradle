//
//  TypedOverrideDiagnostic.swift
//  CradleMacros
//
//  Created by opfic on 9/3/26.
//

import SwiftDiagnostics

// 타입 지정 override의 opt-in과 단계별 지원 범위 진단
enum TypedOverrideDiagnostic: DiagnosticMessage {
	// `overrides` 인자의 정적 Bool literal 제약
	case invalidConfiguration
	// source graph override의 단계별 차단
	case sourceGraphUnsupported
	// actor graph override의 단계별 차단
	case actorGraphUnsupported
	// MainActor graph override의 단계별 차단
	case mainActorGraphUnsupported
	// public graph override의 단계별 차단
	case publicGraphUnsupported
	// override 생성 경로와 충돌하는 사용자 initializer
	case userInitializer
	// override 생성 경로가 초기화할 수 없는 저장 프로퍼티
	case uninitializedStoredProperty
	// generated override 선언 이름 충돌
	case nameCollision(name: String)

	// 경우별 고정 진단 식별자
	var diagnosticID: MessageID {
		switch self {
		case .invalidConfiguration:
			MessageID(domain: "Cradle", id: "invalidOverrideConfiguration")
		case .sourceGraphUnsupported:
			MessageID(domain: "Cradle", id: "overrideSourceGraphUnsupported")
		case .actorGraphUnsupported:
			MessageID(domain: "Cradle", id: "overrideActorGraphUnsupported")
		case .mainActorGraphUnsupported:
			MessageID(domain: "Cradle", id: "overrideMainActorGraphUnsupported")
		case .publicGraphUnsupported:
			MessageID(domain: "Cradle", id: "overridePublicGraphUnsupported")
		case .userInitializer:
			MessageID(domain: "Cradle", id: "overrideUserInitializer")
		case .uninitializedStoredProperty:
			MessageID(domain: "Cradle", id: "overrideUninitializedStoredProperty")
		case .nameCollision:
			MessageID(domain: "Cradle", id: "overrideNameCollision")
		}
	}

	// 경우별 사용자 오류 설명
	var message: String {
		switch self {
		case .invalidConfiguration:
			"`overrides`는 직접 작성한 `true` 또는 `false`여야 합니다."
		case .sourceGraphUnsupported:
			"`sources` graph의 타입 지정 override는 아직 지원하지 않습니다."
		case .actorGraphUnsupported:
			"actor graph의 타입 지정 override는 아직 지원하지 않습니다."
		case .mainActorGraphUnsupported:
			"@MainActor graph의 타입 지정 override는 아직 지원하지 않습니다."
		case .publicGraphUnsupported:
			"public graph의 타입 지정 override는 아직 지원하지 않습니다."
		case .userInitializer:
			"`overrides: true` graph는 initializer를 직접 선언할 수 없습니다."
		case .uninitializedStoredProperty:
			"`overrides: true` graph는 초기값 없는 인스턴스 저장 프로퍼티를 선언할 수 없습니다."
		case let .nameCollision(name):
			"타입 지정 override가 생성할 `\(name)` 이름이 기존 member와 충돌합니다."
		}
	}

	// 지원하지 않는 opt-in은 graph 생성 중단
	var severity: DiagnosticSeverity { .error }
}
