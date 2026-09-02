//
//  CircularDependencyDiagnostic.swift
//  Cradle
//
//  Created by opfic on 8/30/26.
//

import SwiftDiagnostics

// 생성 프로퍼티 사이의 닫힌 순환 경로 안내
struct CircularDependencyDiagnostic: DiagnosticMessage {
	// 첫 등록을 끝에 다시 포함한 프로퍼티 식별자 경로
	let accessorIdentifiers: [String]

	// 순환 경로에 영향을 받지 않는 오류 식별자
	var diagnosticID: MessageID {
		MessageID(domain: "Cradle", id: "circularDependency")
	}

	// 진입 경로를 제외한 실제 순환 경로 표시
	var message: String {
		"`\(accessorIdentifiers.joined(separator: " → "))` 순환 의존성이 있습니다."
	}

	// 순환이 있는 그래프의 컴파일 중단
	var severity: DiagnosticSeverity { .error }
}

// 순환에 포함된 Factory의 원본 등록 위치 안내
struct CircularDependencyProviderNote: NoteMessage {
	// 원본 등록에 선언된 Factory 이름
	let factoryName: String
	// 백틱을 제외한 생성 프로퍼티 식별자
	let accessorIdentifier: String

	// Factory 이름에 영향을 받지 않는 보조 설명 식별자
	var noteID: MessageID {
		MessageID(domain: "Cradle", id: "circularDependencyProvider")
	}

	// 원본 Factory 이름을 한 번만 인용한 등록 설명
	var message: String {
		// 백틱 원문 표기를 보존한 표시용 이름
		let name = if factoryName.hasPrefix("`"), factoryName.hasSuffix("`") {
			factoryName
		} else {
			"`\(factoryName)`"
		}
		return "\(name) Factory의 등록입니다. 생성 프로퍼티는 `\(accessorIdentifier)`입니다."
	}
}
