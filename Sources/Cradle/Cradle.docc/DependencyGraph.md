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

## 매개변수로 의존성 연결

Factory의 매개변수명을 다른 등록의 생성 접근자 이름과 맞추면 의존성을 전달할 수 있습니다. 여기서 매개변수명은 외부 인자 레이블이 아니라 함수 본문에서 사용하는 이름입니다. 다음 예시의 `configuration`과 `logger`는 각각 `configuration()`과 `logger()`에 연결됩니다.

```swift
import Cradle

struct Configuration {
	let endpoint: String
}

final class Logger {}

final class HTTPClient {
	let configuration: Configuration
	let logger: Logger

	init(configuration: Configuration, logger: Logger) {
		self.configuration = configuration
		self.logger = logger
	}
}

@DependencyGraph
final class AppGraph {
	@Provide
	private func makeHTTPClient(
		settings configuration: Configuration,
		_ logger: Logger
	) -> HTTPClient {
		HTTPClient(configuration: configuration, logger: logger)
	}

	@Provide
	private func makeLogger() -> Logger {
		Logger()
	}

	@Provide
	private func makeConfiguration() -> Configuration {
		Configuration(endpoint: "api")
	}
}

let client = AppGraph().httpClient()
```

생성된 `httpClient()`의 호출문은 다음과 같습니다.

```swift
internal func httpClient() -> HTTPClient {
	makeHTTPClient(settings: configuration(), logger())
}
```

연결은 다음 규칙을 따릅니다.

- 매개변수명은 생성 접근자 이름과 대소문자까지 정확히 일치해야 합니다. `urlSession`과 `urlsession`은 서로 다른 이름으로 취급합니다.
- 연결에는 함수 본문에서 사용하는 이름을 쓰고, 호출문에는 외부 인자 레이블을 유지합니다. 외부 레이블이 `_`이면 호출문에서도 생략합니다.
- 의존성의 생성 접근자를 매개변수 순서대로 호출합니다. Factory를 소스 코드에 선언한 순서는 연결 결과를 바꾸지 않습니다.
- 연결 대상은 `@Provide` 등록에서 생성될 접근자로 한정합니다. 같은 이름의 일반 메서드나 호출 가능한 프로퍼티는 의존성 연결 대상으로 사용할 수 없습니다.
- 접근자가 반환하는 값이 매개변수 타입에 맞는지는 Swift 컴파일러가 검사합니다.

의존성을 얻을 때는 Factory를 직접 호출하지 않고 해당 생성 접근자를 호출합니다. Cradle은 아직 생성 결과를 캐시하거나 수명 범위별로 공유하지 않습니다.

## 프로토콜 타입으로 의존성 제공

Factory의 반환 타입을 `any UserRepository`로 선언하면 생성 접근자도 같은 타입을 반환합니다. 구현 타입은 Factory 본문에서 선택하며 의존성을 전달받는 쪽에서는 프로토콜을 사용합니다. 연결은 타입이 아니라 매개변수 이름을 기준으로 합니다.

```swift
import Cradle

protocol UserRepository {
	var name: String { get }
}

struct LiveUserRepository: UserRepository {
	let name = "사용자"
}

struct Profile {
	let repository: any UserRepository
}

@DependencyGraph
final class AppGraph {
	@Provide
	private func makeUserRepository() -> any UserRepository {
		LiveUserRepository()
	}

	@Provide
	private func makeProfile(userRepository: any UserRepository) -> Profile {
		Profile(repository: userRepository)
	}
}

let profile = AppGraph().profile()
```

생성된 접근자는 다음과 같습니다.

```swift
internal func userRepository() -> any UserRepository {
	makeUserRepository()
}

internal func profile() -> Profile {
	makeProfile(userRepository: userRepository())
}
```

`any Domain.UserRepository`처럼 모듈 경로를 붙여도 접근자 이름은 마지막 타입 이름에서 정합니다. 생성 접근자의 반환 타입에는 `any`와 전체 경로를 그대로 유지합니다. 모듈이 달라도 마지막 타입 이름이 같으면 접근자 이름이 중복되므로 함께 등록할 수 없습니다.

매크로는 반환 타입의 문법과 접근자 이름을 검사합니다. 구현 타입의 프로토콜 적합성, 매개변수로 전달할 때의 타입 호환성, 접근 수준과 격리 규칙은 Swift 컴파일러가 검사합니다.

## 선언 조건

`@DependencyGraph`와 `@Provide` 선언은 다음 조건을 만족해야 합니다. 조건을 만족하지 않으면 매크로가 해당 선언을 오류로 진단합니다.

| 대상 | 조건 |
| --- | --- |
| 그래프 | 제네릭 매개변수와 제네릭 `where` 절이 없는 `final class` |
| Factory 위치 | `@DependencyGraph`를 적용한 클래스에 직접 선언 |
| Factory 접근 수준 | `private` |
| Factory 종류 | 인스턴스 메서드 |
| 매개변수 | 생성 접근자와 이름이 일치하며 기본값·가변 인자·`inout`·`@autoclosure`·매개변수명 `_` 없음 |
| 제네릭 | 함수 제네릭 매개변수, 제네릭 `where` 절과 `some` 매개변수 없음 |
| 효과 지정자 | `async`, `throws`, `rethrows` 없음 |
| 반환 선언 | 명시적 반환 타입과 본문 필요 |
| 반환 타입 | 제네릭 인자가 없는 명목 타입 또는 `any`로 표시한 단일 프로토콜 타입 (`any P`, `any Module.P`) |
| 생성 접근자 이름 | 유효한 Swift 함수 이름이며 기존 인스턴스 프로퍼티, 무매개변수 인스턴스 메서드 또는 다른 Factory의 생성 접근자와 중복되지 않음 |

Factory 반환 타입에 Optional, 배열, 딕셔너리, 함수, 튜플과 메타타입 문법을 직접 쓰는 것은 지원하지 않습니다. `(any Service)?`, `[any Service]`, `(any Service).Type`도 여기에 포함됩니다.

`some Service`와 프로토콜 조합인 `any Service & OtherService`도 지원하지 않습니다. `any Service<Value>`나 `any Domain<Value>.Service`처럼 제네릭 인자가 있으면 경로 중간에 있더라도 지원하지 않습니다.

매크로는 작성된 반환 문법만 검사하며 `typealias`가 가리키는 실제 타입은 분석하지 않습니다. 따라서 `typealias Services = [any Service]`로 선언한 별칭 `Services`를 반환 타입으로 쓰면 명목 이름으로 처리합니다.

이 제한은 Factory의 반환 타입에 적용됩니다. 매개변수는 위 표의 조건을 따르므로 `any Service`를 반환하는 접근자의 값을 `(any Service)?` 매개변수에 전달할 수 있습니다.

매개변수 형식이 지원 조건에 맞지 않으면 매크로가 오류를 내고 그래프의 접근자 생성을 모두 중단합니다. 매개변수 형식은 유효하지만 이름이 등록된 생성 접근자와 일치하지 않으면 매크로가 해당 매개변수 위치에 Factory 이름과 지역 이름을 포함한 오류를 내고 `@Provide` 위치에 보조 설명을 추가합니다.

누락 등록 오류가 발생하면 유효한 등록을 포함해 그래프의 생성 접근자를 하나도 생성하지 않습니다. 연결은 계속 이름을 기준으로 하며 누락된 등록까지의 전체 의존성 경로를 추적하는 진단은 아직 지원하지 않습니다.

## 순환 의존성 경로 진단

`@DependencyGraph`와 `@Provide`의 사용법은 그대로입니다. 매크로는 컴파일 시 확장 단계에서 생성 접근자 사이의 순환을 검사합니다. 문법·중복 등록·기존 멤버 충돌·누락 등록 오류가 있으면 해당 오류를 먼저 표시하고 순환 검사는 생략합니다.

같은 그래프의 모든 등록을 선언 순서와 매개변수 순서에 따라 탐색합니다. 아래 구성에서는 `firstService()`가 `secondService()`를, `secondService()`가 `thirdService()`를, `thirdService()`가 다시 `firstService()`를 요구합니다.

```swift
import Cradle

struct FirstService {}
struct SecondService {}
struct ThirdService {}

@DependencyGraph
final class AppGraph {
	@Provide
	private func makeFirstService(secondService: SecondService) -> FirstService { FirstService() }

	@Provide
	private func makeSecondService(thirdService: ThirdService) -> SecondService { SecondService() }

	@Provide
	private func makeThirdService(firstService: FirstService) -> ThirdService { ThirdService() }
}
```

매크로는 순환을 닫는 `makeThirdService`의 매개변수 `firstService`에 오류를 표시합니다. 순환 경로에 포함된 각 Factory의 `@Provide`에는 경로 순서대로 보조 설명을 하나씩 표시합니다.

```text
error: `firstService → secondService → thirdService → firstService` 순환 의존성이 있습니다.
note: `makeFirstService` Factory의 등록입니다. 생성 접근자는 `firstService`입니다.
note: `makeSecondService` Factory의 등록입니다. 생성 접근자는 `secondService`입니다.
note: `makeThirdService` Factory의 등록입니다. 생성 접근자는 `thirdService`입니다.
```

오류 경로는 시작한 접근자로 돌아오는 연결까지 포함합니다. 자기 순환은 `a → a`로 표시합니다. `entry → a → b → a`처럼 순환에 진입하는 경로가 따로 있으면 실제 순환인 `a → b → a`만 표시합니다. 끝에서 반복되는 등록에는 보조 설명을 다시 붙이지 않습니다.

그래프마다 처음 발견한 순환 하나만 오류로 진단합니다. 순환이 있으면 관련 없는 정상 등록을 포함해 해당 그래프의 생성 접근자를 하나도 만들지 않습니다. 표시된 순환을 수정하고 다시 빌드하면 남아 있는 다른 순환을 확인할 수 있습니다.

Optional 타입의 매개변수도 생성 접근자를 즉시 호출하므로 순환 검사에 포함됩니다. Factory 본문에서 직접 작성한 호출, `typealias`의 실제 타입 의미와 실행 중 발생하는 순환은 분석하지 않습니다.

## 생성 접근자 이름

Factory 이름은 생성 접근자 이름에 영향을 주지 않습니다. 매크로는 반환 타입의 마지막 식별자를 lowerCamelCase로 변환해 매개변수가 없는 생성 접근자를 만듭니다.

`typealias`를 사용하면 작성한 별칭 이름을 기준으로 접근자 이름을 만듭니다.

| 반환 타입 | 생성 접근자 |
| --- | --- |
| `TestUseCase` | `testUseCase()` |
| `HTTPClient` | `httpClient()` |
| `any UserRepository` | `userRepository()` |
| `any Domain.UserRepository` | `userRepository()` |
| `URLSession` | `urlSession()` |
| `SHA256` | `sha256()` |
| `HTTP2Client` | `http2Client()` |

### 중복 등록 진단

같은 그래프에서 백틱 표기를 제외한 생성 접근자 이름이 같으면 매크로가 중복 등록을 오류로 진단합니다. Factory 이름을 바꿔도 반환 타입에서 만드는 접근자 이름이 같으면 충돌합니다. 매크로는 `typealias`가 가리키는 실제 타입이나 프로토콜 선언을 분석해 중복을 판단하지 않습니다.

다음 구성에서는 두 Factory의 반환 타입이 모두 `any Repository`여서 생성 접근자 이름 `repository`가 중복됩니다.

```swift
import Cradle

protocol Repository {}
struct FirstRepository: Repository {}
struct SecondRepository: Repository {}

@DependencyGraph
final class AppGraph {
	@Provide
	private func makeFirst() -> any Repository {
		FirstRepository()
	}

	@Provide
	private func makeSecond() -> any Repository {
		SecondRepository()
	}
}
```

매크로는 충돌 그룹에서 처음 선언된 Factory의 반환 타입에 오류 하나를 표시하고 반환 타입 전체를 강조합니다. 위 예시에서는 `makeFirst()`의 `any Repository`를 가리킵니다.

```text
error: `repository` 생성 접근자를 만드는 등록이 중복됩니다.
```

같은 그룹의 모든 `@Provide`에는 Factory 이름과 반환 타입을 담은 보조 설명을 표시합니다. 첫 번째 Factory의 등록 위치도 포함하므로 위 예시에서는 두 보조 설명을 확인할 수 있습니다.

```text
note: `makeFirst` Factory의 등록입니다. 반환 타입은 `any Repository`입니다.
note: `makeSecond` Factory의 등록입니다. 반환 타입은 `any Repository`입니다.
```

등록이 세 개 이상 겹쳐도 그룹마다 오류 하나와 등록 수만큼의 보조 설명을 표시합니다. 그룹과 보조 설명은 Factory 선언 순서를 따릅니다. 첫 번째 Factory는 오류 위치를 정하는 기준일 뿐 우선 등록으로 선택되지 않습니다. 중복이 발견되면 관련 없는 유효 등록을 포함해 그래프의 생성 접근자를 하나도 만들지 않습니다.

## 접근 수준과 초기화

생성 접근자는 그래프와 같은 접근 수준을 가집니다. `public` 그래프를 다른 모듈에서 사용하려면 그래프가 `public init()`을 직접 선언해야 합니다. `public` 생성 접근자의 반환 타입도 외부에서 접근할 수 있어야 합니다.

따라서 `public` 그래프가 `any UserRepository`를 반환하려면 `UserRepository`도 `public`이어야 합니다. Factory 내부의 구현 타입까지 공개할 필요는 없습니다. `internal` 프로토콜을 반환하면 Swift 컴파일러가 생성 접근자의 접근 수준을 오류로 진단합니다.

매크로는 그래프에 생성자를 추가하지 않으며 사용자가 선언한 생성자와 인스턴스 저장 프로퍼티도 변경하지 않습니다. 그래프에 필요한 값과 상태는 클래스에 직접 선언합니다.

## 현재 지원 범위

현재 `@DependencyGraph`는 그래프 클래스에 생성 접근자를 추가합니다. `@Provide`에는 동기 Factory를 등록하고 매개변수로 직접·다단계 의존성을 연결할 수 있습니다. 다음 기능은 아직 지원하지 않습니다.

- 등록 한정자
- 캐시와 수명 범위 관리
- 등록 재정의
- 그래프 간 연결
- `async`, `throws` Factory
- 누락 등록까지의 전체 의존성 경로 진단
