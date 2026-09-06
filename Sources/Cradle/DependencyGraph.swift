//
//  DependencyGraph.swift
//  Cradle
//
//  Created by opfic on 8/29/26.
//

// private `@Provide` Factory에서 생성 접근자를 추가할 final class·actor graph 선언
// 명목 타입과 `any Protocol` 반환 타입을 보존한 생성 접근자 추가
// 모듈 경로가 붙은 프로토콜도 마지막 타입 이름을 기준으로 접근자 이름 생성
//
// provider 매개변수의 지역 이름을 등록 생성 접근자와 연결
// final class `sources` source graph 저장 프로퍼티와 생성 initializer 추가
// `overrides: true` graph의 인스턴스별 Factory 선택 builder와 생성 경로 추가
// source·override가 없는 graph의 initializer·stored property 미변경
/**
 `@Provide` Factory로 의존성을 등록하고 생성 접근자를 만드는 graph Macro입니다.

 제네릭 매개변수와 `where` 절이 없는 `final class` 또는 `actor`에 적용합니다.
 일반 `@Provide` Factory의 반환 타입을 기준으로 graph에 읽기 전용 생성 프로퍼티를 추가합니다.

 - Parameters:
   - lifetime: graph 인스턴스의 보유 범위입니다. 기본값은 `.instance`이며, `.shared`는 프로세스 동안
     보유하는 `static let shared` graph를 만듭니다.
   - sources: `final class` 조합 graph가 보관하고 Factory에서 읽을 source graph 타입 배열입니다.
     기본값은 빈 배열입니다.
   - overrides: graph 인스턴스별 Factory 교체를 위한 `override`와 `OverrideBuilder` 생성 여부입니다.
     기본값은 `false`입니다.
   - diagram: `CradlePlugin`의 Mermaid 개발 산출물에 해당 graph를 포함할지 정하는 값입니다.
     기본값은 `true`입니다.
 - Important: `actor` graph에는 `sources`를 사용할 수 없습니다. `sources` 또는 `overrides: true`를
   사용한 graph에는 initializer를 직접 선언할 수 없습니다.
 - SeeAlso: <doc:DependencyGraph>
 */
@attached(member, names: arbitrary)
public macro DependencyGraph(
	_ lifetime: DependencyGraphLifetime = .instance,
	sources: [Any.Type] = [],
	overrides: Bool = false,
	diagram: Bool = true
) = #externalMacro(
	module: "CradleMacros",
	type: "DependencyGraphMacro"
)

// `@DependencyGraph` 본체에서 생성 접근자가 호출할 private factory 표시
/**
 기본 `.shared` 수명으로 의존성을 등록하는 Factory Macro입니다.

 `@DependencyGraph` 본체에 직접 선언한 동기 `private` 인스턴스 메서드에 적용합니다.
 Factory 결과는 graph를 만들 때 한 번 생성되고 해당 graph가 보관합니다.

 - Important: 호출 시점 입력이 필요하면 `@Provide(.transient)`와 `@External`을 함께 사용합니다.
 - SeeAlso: <doc:DependencyGraph>
 */
@attached(peer, names: arbitrary)
@attached(body)
public macro Provide() = #externalMacro(
	module: "CradleMacros",
	type: "ProvideMacro"
)

// Factory 결과를 graph 수명 정책에 맞게 소유하도록 표시
/**
 지정한 수명 정책으로 의존성을 등록하는 Factory Macro입니다.

 `@DependencyGraph` 본체에 직접 선언한 동기 `private` 인스턴스 메서드에 적용합니다.
 외부 입력이 없는 Factory의 반환 타입이 등록 타입과 생성 접근자의 타입이 됩니다.

 - Parameter lifetime: Factory 결과의 graph별 보유 정책입니다. `.shared`는 graph 생성 중 한 번,
   `.lazy`는 생성 프로퍼티를 처음 읽을 때 한 번, `.transient`는 접근할 때마다 Factory를 평가합니다.
 - Important: `@External` 입력은 명시적인 `.transient` Factory에서만 사용할 수 있으며, 이때 Macro는
   호출 시점 생성 메서드를 만듭니다.
 - SeeAlso: <doc:DependencyGraph>
 */
@attached(peer, names: arbitrary)
@attached(body)
public macro Provide(_ lifetime: DependencyLifetime) = #externalMacro(
	module: "CradleMacros",
	type: "ProvideMacro"
)
