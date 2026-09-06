//
//  ProviderLifetimeReferenceDiagnostic.swift
//  CradleMacros
//
//  Created by opfic on 9/6/26.
//

import SwiftDiagnostics

// graph 보관 수명 조합의 원본 매개변수 진단
enum ProviderLifetimeReferenceDiagnostic: DiagnosticMessage {
	// eager shared Factory가 lazy 등록을 앞당기는 연결
	case sharedLazy
	// lazy Factory가 transient 결과를 보관하는 연결
	case lazyTransient

	// 수명 조합별 고정 진단 식별자
	var diagnosticID: MessageID {
		switch self {
		case .sharedLazy:
			MessageID(domain: "Cradle", id: "invalidSharedLazyProviderReference")
		case .lazyTransient:
			MessageID(domain: "Cradle", id: "invalidLazyProviderReference")
		}
	}

	// 수명 조합별 소비자 안내
	var message: String {
		switch self {
		case .sharedLazy:
			"shared 수명의 `@Provide` Factory는 `.lazy` 등록을 매개변수로 받을 수 없습니다."
		case .lazyTransient:
			"lazy 수명의 `@Provide` Factory는 `.transient` 등록을 매개변수로 받을 수 없습니다."
		}
	}

	// 컴파일 중단 오류
	var severity: DiagnosticSeverity { .error }
}

// graph 보관 수명 조합의 원본 매개변수 진단 반환
func providerLifetimeReferenceDiagnostic(
	providerLifetime: ProviderLifetime,
	dependencyLifetime: ProviderLifetime
) -> (any DiagnosticMessage)? {
	switch (providerLifetime, dependencyLifetime) {
	case (.shared, .transient):
		InvalidSharedProviderReferenceDiagnostic()
	case (.shared, .lazy):
		ProviderLifetimeReferenceDiagnostic.sharedLazy
	case (.lazy, .transient):
		ProviderLifetimeReferenceDiagnostic.lazyTransient
	default:
		nil
	}
}
