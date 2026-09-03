# CradleTesting

`CradleTesting`은 `@DependencyGraph(overrides: true)` graph에서 테스트 대역 Factory를 선택하는 `DependencyOverride.mock(_:)`을 제공합니다. 이 product는 `Cradle`과 분리되어 있으므로 테스트 target에서만 선택적으로 import할 수 있습니다.

## Overview

테스트 target은 graph 선언과 Macro를 위해 `Cradle`을, `.mock` 편의 API를 위해 `CradleTesting`을 함께 import합니다. `.mock`은 Factory를 실행하지 않고 기존 `.replace` 상태로 감싸며, graph 생성은 기존 `Graph.override(...).build()` 경로를 사용합니다.

```swift
import Cradle
import CradleTesting

let graph = AppGraph.override(
	userRepository: .mock {
		StubUserRepository()
	}
).build()
```

`.mock`에 전달하는 closure의 매개변수와 반환 타입은 등록한 `@Provide` Factory의 계약을 따릅니다. concrete 타입, `any Protocol`, superclass 반환 Factory는 Swift compiler가 같은 방식으로 검사합니다. 존재하지 않거나 중복된 등록 label, 맞지 않는 Factory 형식은 compiler가 호출 원본 위치에서 진단합니다.

## 원본 등록 유지

테스트에서 mock을 지정하지 않은 등록은 오류가 아닙니다. `Graph.override(...)`의 생략한 매개변수는 `.original`이므로 선언한 Factory와 수명 정책을 그대로 사용합니다.

```swift
let graph = AppGraph.override(
	userRepository: .mock {
		StubUserRepository()
	}
).build()
```

위 구성에서 `userRepository`만 테스트 대역으로 교체하며 나머지 등록은 원본 Factory를 사용합니다. `.original`을 명시해 같은 선택을 나타낼 수도 있습니다.

## 수명과 graph 격리

shared mock Factory는 builder를 만들 때 실행하지 않으며 각 `.build()`에서 한 번 실행합니다. 같은 graph는 그 결과를 재사용하고, 같은 builder로 만든 다른 graph는 별도의 shared 인스턴스를 소유합니다.

transient mock Factory도 builder와 `.build()`에서 실행하지 않습니다. 생성 프로퍼티에 접근할 때마다 Factory를 호출하며, 필요한 shared 등록은 해당 graph가 보관한 값을 전달합니다.

`.mock`은 전역 registry나 실행 중 조회 API를 만들지 않습니다. override 선택과 shared 값은 모두 만든 graph 인스턴스에만 적용됩니다.

## actor graph

actor graph의 mock Factory는 기존 `override` API와 같이 `@Sendable` closure여야 합니다. non-`Sendable` 값의 capture와 actor 밖으로 반환하는 값의 경계는 Swift compiler가 검사합니다.

```swift
let graph = SessionGraph.override(
	session: .mock {
		StubSession()
	}
).build()
```

서로 다른 actor graph를 병렬로 만들면 각 graph는 override 선택과 shared 값을 분리해 보관합니다. `CradleTesting`은 actor 격리를 우회하는 `@unchecked Sendable`, `nonisolated`, lock을 추가하지 않습니다.
