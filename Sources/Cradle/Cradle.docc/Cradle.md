# ``Cradle``

Cradle은 Swift 매크로로 의존성의 생성과 연결에 필요한 코드를 만드는 Swift 라이브러리입니다.

## Overview

`@DependencyGraph`는 비 generic `final class` 또는 비 generic `actor`에 적용합니다. graph 안의 동기 `private` Factory에 `@Provide`를 붙이면 의존성을 등록할 수 있습니다. Factory의 반환 타입이 등록 타입과 graph가 노출하는 읽기 전용 프로퍼티 타입이 됩니다.

Factory 매개변수는 이름이 아니라 타입으로 다른 등록과 연결합니다. 외부 인자 레이블과 매개변수 순서는 Factory 호출에 그대로 유지합니다. 호출할 때 정해지는 값은 명시적인 `@Provide(.transient)` Factory 매개변수에 `@External`을 붙여 생성 메서드의 입력으로 분리할 수 있습니다.

Factory가 `any UserRepository`를 반환하면 graph의 `userRepository`도 같은 프로토콜 타입을 노출합니다. 구현 타입의 프로토콜 적합성은 Swift 컴파일러가 검사합니다.

기본 `@Provide`와 `@Provide(.shared)`는 graph 생성 중 한 번 만든 값을 해당 graph가 보유하고 이후 같은 값을 반환합니다. 이 값은 전역 싱글턴이 아니라 graph 인스턴스마다 분리됩니다. 프로퍼티를 읽을 때마다 Factory를 호출해야 하면 `@Provide(.transient)`를 사용합니다.

actor graph의 생성 프로퍼티는 actor 격리를 따릅니다. actor 밖에서는 `await`로 읽으며, 반환 값이 actor 경계를 통과할 수 있는지는 Swift 컴파일러가 `Sendable` 규칙으로 검사합니다.

`@DependencyGraph(overrides: true)`를 지정하면 등록별 기본값이 `.original`인 static `override`와 `OverrideBuilder.build()`를 사용할 수 있습니다. builder는 교체 선택만 보관하고 `.build()`에서 graph와 shared 등록을 만듭니다. actor 교체 Factory는 `@Sendable`이어야 하며, `@MainActor` graph의 builder는 같은 격리를 따릅니다.

class graph는 동시 접근을 조정하지 않습니다. 여러 Task에서 공유해야 하면 단일 소유자로 사용하거나 `@MainActor`처럼 명시한 전역 actor 격리 안에 둡니다.

`sources`와 `overrides: true`를 모두 지정하지 않은 graph에서는 매크로가 생성자를 추가하지 않으며 사용자가 선언한 생성자와 인스턴스 저장 프로퍼티도 변경하지 않습니다. `sources` 또는 `overrides: true` graph는 생성 경로를 Macro가 소유합니다.

SwiftPM target에 `CradlePlugin`을 연결하면 build마다 의존성 관계를 Mermaid `.mmd` 개발 산출물로 갱신합니다. 이 산출물은 plugin work directory에만 남으며 library와 app binary에는 포함되지 않습니다.

## Topics

### 사용 안내

- <doc:DependencyGraph>

### 매크로

- ``DependencyGraph(sources:overrides:diagram:)``
- ``DependencyOverride``
- ``External``
- ``Provide()``
- ``Provide(_:)``
- ``DependencyLifetime``
