# ``Cradle``

Cradle은 Swift 매크로로 의존성의 생성과 연결에 필요한 코드를 만드는 Swift 라이브러리입니다.

## Overview

`@DependencyGraph`는 `final class`에 적용합니다. 그래프 안의 동기 `private` Factory에 `@Provide`를 붙이면 의존성을 등록할 수 있습니다. Factory의 반환 타입이 등록 타입과 graph가 노출하는 읽기 전용 프로퍼티 타입이 됩니다.

Factory 매개변수는 이름이 아니라 타입으로 다른 등록과 연결합니다. 외부 인자 레이블과 매개변수 순서는 Factory 호출에 그대로 유지합니다.

Factory가 `any UserRepository`를 반환하면 graph의 `userRepository`도 같은 프로토콜 타입을 노출합니다. 구현 타입의 프로토콜 적합성은 Swift 컴파일러가 검사합니다.

기본 `@Provide`와 `@Provide(.shared)`는 graph 생성 중 한 번 만든 값을 해당 graph가 보유하고 이후 같은 값을 반환합니다. 이 값은 전역 싱글턴이 아니라 graph 인스턴스마다 분리됩니다. 프로퍼티를 읽을 때마다 Factory를 호출해야 하면 `@Provide(.transient)`를 사용합니다.

매크로는 그래프에 생성자를 추가하지 않으며 사용자가 선언한 생성자와 인스턴스 저장 프로퍼티도 변경하지 않습니다. 그래프를 외부 모듈에서 생성해야 한다면 필요한 생성자를 직접 선언합니다.

## Topics

### 사용 안내

- <doc:DependencyGraph>

### 매크로

- ``DependencyGraph(sources:)``
- ``Provide()``
- ``Provide(_:)``
- ``DependencyLifetime``
