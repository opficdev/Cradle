# DependencyGraph로 의존성 등록

`@DependencyGraph`와 `@Provide`를 함께 사용하면 Factory의 반환 타입별 읽기 전용 프로퍼티를 graph에 추가합니다. `@Provide`는 의존성을 등록하고, graph 프로퍼티는 등록된 의존성을 읽는 지점입니다.

## 기본 선언

Factory의 이름은 자유롭게 정할 수 있습니다. 반환 타입이 등록 타입과 생성 프로퍼티의 타입이 되며, 반환 타입의 마지막 식별자를 lowerCamelCase로 바꾼 이름이 프로퍼티가 됩니다.

```swift
import Cradle

public final class HTTPClient {
	public init() {}
}

@DependencyGraph
public final class AppGraph {
	public init() {}

	@Provide
	private func provideHTTPClient() -> HTTPClient {
		HTTPClient()
	}
}

let graph = AppGraph()
let client = graph.httpClient
```

기본 `@Provide`는 transient 등록입니다. `graph.httpClient`에 접근할 때마다 Factory를 호출하므로, Factory가 새 값을 반환하면 매번 새 값을 얻습니다.

| 반환 타입 | 생성 프로퍼티 |
| --- | --- |
| `TestUseCase` | `testUseCase` |
| `HTTPClient` | `httpClient` |
| `any UserRepository` | `userRepository` |
| `any Domain.UserRepository` | `userRepository` |
| `URLSession` | `urlSession` |
| `SHA256` | `sha256` |
| `HTTP2Client` | `http2Client` |

## source graph 조합

`sources`에는 조합 graph가 직접 읽을 source graph type을 `GraphType.self` 배열로 지정합니다. Macro는 source type의 마지막 식별자를 lowerCamelCase로 바꾼 `private let` 저장 프로퍼티와 graph 접근 수준의 initializer를 만듭니다. 조합 Factory 본문에서는 이 저장 프로퍼티로 source graph의 생성 프로퍼티를 직접 읽습니다.

```swift
import Cradle

final class Repository {}
final class Session {}

final class Feature {
	let repository: Repository
	let session: Session

	init(repository: Repository, session: Session) {
		self.repository = repository
		self.session = session
	}
}

@DependencyGraph
final class AppGraph {
	@Provide
	private func makeRepository() -> Repository {
		Repository()
	}
}

@DependencyGraph
final class SessionGraph {
	@Provide
	private func makeSession() -> Session {
		Session()
	}
}

@DependencyGraph(sources: [SessionGraph.self, AppGraph.self])
final class FeatureGraph {
	@Provide
	private func makeFeature() -> Feature {
		Feature(
			repository: appGraph.repository,
			session: sessionGraph.session
		)
	}
}

let graph = FeatureGraph(appGraph: AppGraph(), sessionGraph: SessionGraph())
let feature = graph.feature
```

`sources` 배열의 순서는 의미가 없습니다. Macro는 source type의 정규화한 이름순으로 저장 프로퍼티와 initializer 매개변수를 생성하므로, 위 예시의 initializer 매개변수도 `appGraph`, `sessionGraph` 순서입니다. 같은 source type을 중복하거나 서로 같은 저장 프로퍼티 이름을 만들면 오류를 냅니다.

조합 graph는 source graph를 강하게 보관합니다. source graph의 shared 생성 프로퍼티는 source graph마다 같은 값을 반환하고, transient 생성 프로퍼티는 조합 graph가 읽을 때마다 source Factory를 다시 호출합니다. source 생성 프로퍼티가 없거나 접근 수준이 맞지 않거나 반환 타입이 맞지 않으면 Macro가 대신 연결하지 않으며 Swift 컴파일러가 원본 Factory 본문에서 오류를 표시합니다.

## 타입으로 의존성 연결

Factory 매개변수 타입이 다른 Factory의 반환 타입과 같으면 Macro가 두 등록을 연결합니다. Factory 이름과 매개변수의 지역 이름은 등록 선택에 영향을 주지 않습니다. 외부 인자 레이블과 매개변수 순서는 생성한 Factory 호출에 그대로 유지합니다.

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
	private func buildHTTPClient(
		settings configuration: Configuration,
		_ logger: Logger
	) -> HTTPClient {
		HTTPClient(configuration: configuration, logger: logger)
	}

	@Provide
	private func createLogger() -> Logger {
		Logger()
	}

	@Provide
	private func createConfiguration() -> Configuration {
		Configuration(endpoint: "api")
	}
}

let client = AppGraph().httpClient
```

위 예시에서 `Configuration`과 `Logger`가 연결 기준입니다. `buildHTTPClient`의 `settings` 레이블과 `_` 레이블은 Factory 호출에 그대로 반영됩니다.

등록이 없는 매개변수 타입은 원본 매개변수 타입 위치에서 오류로 진단합니다. 같은 등록 타입을 둘 이상 반환하거나 생성 프로퍼티 이름이 기존 멤버 또는 다른 등록과 겹치면 graph의 프로퍼티를 생성하지 않습니다.

## 프로토콜과 superclass 반환 타입

Factory는 protocol 또는 superclass를 반환 타입으로 선언할 수 있습니다. 생성 프로퍼티도 선언한 반환 타입을 그대로 노출하고, 구현 타입이 그 타입에 대입 가능한지는 Swift 컴파일러가 검사합니다.

```swift
import Cradle

protocol UserRepository {
	func load() -> String
}

struct LiveUserRepository: UserRepository {
	func load() -> String { "사용자" }
}

struct Profile {
	let repository: any UserRepository
}

@DependencyGraph
final class AppGraph {
	@Provide(.shared)
	private func provideUserRepository() -> any UserRepository {
		LiveUserRepository()
	}

	@Provide
	private func provideProfile(repository: any UserRepository) -> Profile {
		Profile(repository: repository)
	}
}

let graph = AppGraph()
let profile = graph.profile
```

`P`와 `any P`는 연결과 중복 검사에서 같은 등록 타입으로 취급합니다. Macro는 `typealias`가 가리키는 실제 타입, import로 생략한 모듈 경로, protocol·superclass 선언의 의미를 해석하지 않습니다.

## shared 수명

`@Provide(.shared)`는 graph를 만들 때 Factory 결과를 한 번 생성하고, graph 전용의 타입 지정 `let` 저장소가 이를 보유하게 합니다. 같은 graph에서 해당 생성 프로퍼티를 여러 번 읽으면 같은 값을 반환합니다. graph가 해제되면 저장소가 보유한 참조도 함께 놓습니다.

```swift
@DependencyGraph
final class AppGraph {
	@Provide(.shared)
	private func provideRepository() -> any UserRepository {
		LiveUserRepository()
	}
}

let graph = AppGraph()
let first = graph.userRepository
let second = graph.userRepository
```

shared Factory는 다른 shared 등록만 매개변수로 받을 수 있습니다. shared Factory가 transient 등록을 받으면 그 transient 값이 graph 생성 때 한 번 만들어져 shared 값에 고정되므로, Macro는 해당 매개변수 타입 위치에 오류를 표시합니다. 반대로 transient Factory는 shared 등록을 매개변수로 받을 수 있습니다.

shared Factory 본문은 사용자가 작성한 initializer 본문보다 먼저 실행됩니다. 따라서 `self`, `super`, graph 인스턴스 멤버, 다른 Factory를 직접 참조할 수 없습니다. 필요한 shared 의존성은 Factory 매개변수로 선언합니다.

source graph 저장 프로퍼티도 graph 인스턴스 멤버이므로 shared Factory에서 읽을 수 없습니다. source 값이 필요한 Factory는 기본 `@Provide`로 선언합니다.

## 본문 없는 Factory

본문이 없는 Factory에는 선언한 반환 타입의 initializer 호출을 자동으로 추가합니다. 매개변수의 외부 레이블과 순서는 initializer 호출에도 유지합니다.

```swift
struct Host {}

struct Configuration {
	init(host: Host) {}
}

@DependencyGraph
final class AppGraph {
	@Provide
	private func configuration(host: Host) -> Configuration

	@Provide
	private func host() -> Host {
		Host()
	}
}
```

위 Factory의 본문은 `(Configuration).init(host: host)`를 반환하는 형태로 확장됩니다. protocol처럼 구현 타입을 선택해야 하거나 initializer를 호출할 수 없는 반환 타입에는 본문을 직접 작성합니다. 본문이 없는 Factory의 initializer 호출이 성립하지 않으면 Swift 컴파일러가 오류를 냅니다.

## 선언 조건과 진단

`@DependencyGraph`는 제네릭 매개변수와 제네릭 `where` 절이 없는 `final class`에만 적용합니다. `@Provide` Factory는 graph 본체에 직접 선언한 동기 `private` 인스턴스 메서드여야 하며, 명시적 반환 타입이 필요합니다.

`@Provide` 매개변수에는 기본값, 가변 인자, `inout`, `@autoclosure`, `some`, `_` 지역 이름을 사용할 수 없습니다. `async`, `throws`, `rethrows`, 함수 제네릭, 타입 메서드도 사용할 수 없습니다.

Factory 반환 타입과 매개변수 타입에는 직접 작성한 Optional을 사용할 수 없습니다. `Service?`, `Optional<Service>`, `Swift.Optional<Service>`가 여기에 포함됩니다. Macro는 Optional을 대체할 `nil` 경로를 만들지 않습니다.

반환 타입은 프로퍼티 이름을 만들 수 있는 명목 타입 또는 `any`를 사용한 단일 protocol 타입이어야 합니다. `Array<Service>`와 `Dictionary<Key, Value>`처럼 이름으로 작성한 제네릭 명목 타입은 사용할 수 있지만, `[Service]`, `[Key: Value]` 축약 문법은 지원하지 않습니다. 함수, 튜플, 메타타입, `some` 타입, protocol 조합도 등록 타입으로 지원하지 않습니다. `typealias`가 가리키는 실제 타입은 분석하지 않습니다.

유효한 graph에서는 누락 등록, 중복 등록, 기존 멤버 충돌, shared → transient 참조, 순환 의존성을 컴파일 중 진단합니다. 이런 오류가 있으면 관련 없는 등록을 포함해 graph 프로퍼티를 생성하지 않습니다.

## 접근 수준과 초기화

생성 프로퍼티는 graph와 같은 접근 수준을 가집니다. `public` graph를 다른 모듈에서 만들려면 `public init()`을 직접 선언해야 합니다. `public` 생성 프로퍼티의 반환 타입도 외부 모듈에서 접근할 수 있어야 합니다.

`sources`가 없는 graph에서는 Macro가 생성자를 추가하지 않으며 사용자가 선언한 생성자와 인스턴스 저장 프로퍼티를 바꾸지 않습니다. 반면 `sources` graph는 source 저장 프로퍼티를 초기화할 생성자를 Macro가 만듭니다. 이때 사용자가 initializer를 직접 선언하거나 초기값 없는 인스턴스 저장 프로퍼티를 선언하면 오류를 냅니다.

`sources` graph가 protocol만 채택하면 생성 initializer가 그대로 protocol 채택을 유지합니다. superclass를 상속한 `sources` graph에는 Macro가 `super.init()`을 생성하지 않습니다. superclass initializer 호출이 필요하면 Swift 컴파일러가 생성 initializer에서 오류를 표시합니다.

## 현재 지원 범위

현재 `@DependencyGraph`는 동기 Factory의 타입 기반 연결과 transient·shared 수명만 지원합니다. 다음 기능은 아직 지원하지 않습니다.

- 등록 재정의
- source graph 생성 프로퍼티의 자동 주입
- qualifier와 multibinding
- graph 입력과 assisted factory
- actor graph와 부모·자식 graph
- `async`, `throws`, `rethrows` Factory
- 구체 구현 타입 자동 탐색
