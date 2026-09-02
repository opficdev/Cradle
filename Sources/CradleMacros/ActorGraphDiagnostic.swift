//
//  ActorGraphDiagnostic.swift
//  CradleMacros
//
//  Created by opfic on 9/3/26.
//

import SwiftDiagnostics

// actor graph에 허용하지 않는 source 조합 진단
enum ActorGraphDiagnostic: DiagnosticMessage {
	case sourcesUnsupported

	// actor graph source 조합 진단 식별자
	var diagnosticID: MessageID {
		MessageID(domain: "Cradle", id: "actorSourcesUnsupported")
	}

	// actor graph source 조합 오류 설명
	var message: String {
		"actor `@DependencyGraph`에는 `sources`를 지정할 수 없습니다."
	}

	// actor graph source 조합 오류 심각도
	var severity: DiagnosticSeverity { .error }
}
