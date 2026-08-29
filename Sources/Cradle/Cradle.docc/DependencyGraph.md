# DependencyGraph로 생성 접근자 구성

`@DependencyGraph`와 `@Provide`를 함께 사용하면 매크로가 각 `private` Factory의 반환 타입을 기준으로 생성 접근자를 추가합니다.

## 기본 선언

다음 예시에서 매크로는 `makeHTTPClient()`의 반환 타입인 `HTTPClient`를 바탕으로 `httpClient()` 생성 접근자를 추가합니다.

```swift
import Cradle

public final class HTTPClient {
	public init() {}
}

@DependencyGraph
public final class AppGraph {
	public init() {}

	@Provide
	private func makeHTTPClient() -> HTTPClient {
		HTTPClient()
	}
}

let graph = AppGraph()
let client = graph.httpClient()
```

생성 접근자는 호출할 때마다 `private` Factory를 직접 호출합니다. 위 예시의 `makeHTTPClient()`는 새 `HTTPClient`를 반환하므로 `graph.httpClient()`를 호출할 때마다 새 인스턴스를 얻습니다. Cradle은 현재 Factory 결과를 캐시하지 않습니다.

## 선언 조건

`@DependencyGraph`와 `@Provide` 선언은 다음 조건을 만족해야 합니다. 조건을 만족하지 않으면 매크로가 해당 선언을 오류로 진단합니다.

| 대상 | 조건 |
| --- | --- |
| 그래프 | 제네릭 매개변수와 제네릭 `where` 절이 없는 `final class` |
| Factory 위치 | `@DependencyGraph`를 적용한 클래스에 직접 선언 |
| Factory 접근 수준 | `private` |
| Factory 종류 | 인스턴스 메서드 |
| 매개변수 | 없음 |
| 제네릭 | 함수 제네릭 매개변수와 제네릭 `where` 절 없음 |
| 효과 지정자 | `async`, `throws`, `rethrows` 없음 |
| 반환 선언 | 명시적 반환 타입과 본문 필요 |
| 반환 타입 | 제네릭 인자가 없는 구체 명목 타입 |
| 생성 접근자 이름 | 유효한 Swift 함수 이름이며 기존 인스턴스 프로퍼티, 무매개변수 인스턴스 메서드 또는 다른 Factory와 중복되지 않음 |

`Service?`, `[Service]`, `any Service`, `some Service`, 함수 타입과 튜플은 지원하지 않습니다. 모듈 경로가 붙은 구체 명목 타입은 마지막 타입 이름을 기준으로 생성 접근자 이름을 만듭니다.

## 생성 접근자 이름

Factory 이름은 생성 접근자 이름에 영향을 주지 않습니다. 매크로는 반환 타입의 마지막 식별자를 lowerCamelCase로 변환해 매개변수가 없는 생성 접근자를 만듭니다.

| 반환 타입 | 생성 접근자 |
| --- | --- |
| `TestUseCase` | `testUseCase()` |
| `HTTPClient` | `httpClient()` |
| `URLSession` | `urlSession()` |
| `SHA256` | `sha256()` |
| `HTTP2Client` | `http2Client()` |

## 접근 수준과 초기화

생성 접근자는 그래프와 같은 접근 수준을 가집니다. `public` 그래프를 다른 모듈에서 사용하려면 그래프가 `public init()`을 직접 선언해야 합니다. `public` 생성 접근자의 반환 타입도 외부에서 접근할 수 있어야 합니다.

매크로는 그래프에 생성자를 추가하지 않으며 사용자가 선언한 생성자와 인스턴스 저장 프로퍼티도 변경하지 않습니다. 그래프에 필요한 값과 상태는 클래스에 직접 선언합니다.

## 현재 지원 범위

현재 `@DependencyGraph`는 그래프 클래스에 생성 접근자를 추가합니다. `@Provide`에는 매개변수가 없는 동기 Factory만 등록할 수 있습니다. 다음 기능은 아직 지원하지 않습니다.

- Factory 매개변수를 이용한 의존성 연결
- 프로토콜과 구현 타입 연결 및 등록 한정자
- 캐시와 수명 범위 관리
- 등록 재정의
- 그래프 간 연결
- `async`, `throws` Factory
