//
//  SourceGraphDiagnostic.swift
//  CradleMacros
//
//  Created by opfic on 9/2/26.
//

import SwiftDiagnostics

// source graph 선언과 생성 initializer 충돌 진단
enum SourceGraphDiagnostic: DiagnosticMessage {
	// `sources` 인자 형식 오류
	case invalidSources
	// 비어 있는 source 배열 오류
	case emptySources
	// source 배열 원소 형식 오류
	case invalidSource
	// 같은 source type 중복 오류
	case duplicateSource(type: String)
	// source 저장 프로퍼티 이름 충돌 오류
	case sourceNameCollision(name: String)
	// 사용자 initializer 충돌 오류
	case userInitializer
	// 초기값 없는 저장 프로퍼티 충돌 오류
	case uninitializedStoredProperty
	// shared Factory의 source 참조 오류
	case sharedSourceReference(name: String)

	// source graph 진단 식별자
	var diagnosticID: MessageID {
		switch self {
		case .invalidSources:
			MessageID(domain: "Cradle", id: "invalidSources")
		case .emptySources:
			MessageID(domain: "Cradle", id: "emptySources")
		case .invalidSource:
			MessageID(domain: "Cradle", id: "invalidSource")
		case .duplicateSource:
			MessageID(domain: "Cradle", id: "duplicateSource")
		case .sourceNameCollision:
			MessageID(domain: "Cradle", id: "sourceNameCollision")
		case .userInitializer:
			MessageID(domain: "Cradle", id: "sourceUserInitializer")
		case .uninitializedStoredProperty:
			MessageID(domain: "Cradle", id: "sourceUninitializedStoredProperty")
		case .sharedSourceReference:
			MessageID(domain: "Cradle", id: "sharedSourceReference")
		}
	}

	// source graph 진단 문구
	var message: String {
		switch self {
		case .invalidSources:
			"`sources`에는 `GraphType.self` 배열 리터럴만 지정할 수 있습니다."
		case .emptySources:
			"`sources`에는 하나 이상의 `GraphType.self`이 필요합니다."
		case .invalidSource:
			"`sources` 원소는 `GraphType.self` 형식이어야 합니다."
		case let .duplicateSource(type):
			"`\(type)` source graph가 중복되었습니다."
		case let .sourceNameCollision(name):
			"`\(name)` source 저장 프로퍼티 이름이 충돌합니다."
		case .userInitializer:
			"`sources` graph는 initializer를 직접 선언할 수 없습니다."
		case .uninitializedStoredProperty:
			"`sources` graph는 초기값 없는 인스턴스 저장 프로퍼티를 선언할 수 없습니다."
		case let .sharedSourceReference(name):
			"`@Provide(.shared)` Factory는 `\(name)` source graph를 참조할 수 없습니다."
		}
	}

	// source graph 진단 severity
	var severity: DiagnosticSeverity { .error }
}

// source graph 중복과 이름 충돌의 첫 선언 위치 표시
struct SourceGraphNote: NoteMessage {
	// 보조 설명 대상 source graph type
	let type: String

	// source graph 보조 설명 식별자
	var noteID: MessageID {
		MessageID(domain: "Cradle", id: "sourceGraph")
	}

	// source graph 보조 설명 문구
	var message: String {
		"`\(type)` source graph가 여기에서 선언되었습니다."
	}
}
