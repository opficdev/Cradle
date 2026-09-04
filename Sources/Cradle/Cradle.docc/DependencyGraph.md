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

기본 `@Provide`는 graph 생성 중 한 번 만드는 shared 등록입니다. `graph.httpClient`를 여러 번 읽어도 같은 값을 반환하며, 이 값은 전역 싱글턴이 아니라 해당 graph 인스턴스에만 보관됩니다. 접근할 때마다 새 값을 만들어야 하면 `@Provide(.transient)`를 사용합니다.

| 반환 타입 | 생성 프로퍼티 |
| --- | --- |
| `TestUseCase` | `testUseCase` |
| `HTTPClient` | `httpClient` |
| `any UserRepository` | `userRepository` |
| `any Domain.UserRepository` | `userRepository` |
| `URLSession` | `urlSession` |
| `SHA256` | `sha256` |
| `HTTP2Client` | `http2Client` |

## graph 인스턴스별 Factory 교체

테스트, Preview, 기능별 조립처럼 graph 인스턴스마다 다른 구현이 필요하면 `overrides: true`를 지정합니다. Macro는 등록별 `DependencyOverride<Factory>` 매개변수를 가진 static `override`와 `OverrideBuilder`를 만듭니다. `override`에 전달하지 않은 등록은 모두 `.original`이므로 선언한 Factory를 그대로 사용합니다.

```swift
import Cradle

protocol UserRepository {
	func load() -> String
}

struct LiveUserRepository: UserRepository {
	func load() -> String { "운영" }
}

struct StubUserRepository: UserRepository {
	func load() -> String { "테스트" }
}

@DependencyGraph(overrides: true)
final class AppGraph {
	@Provide
	private func makeUserRepository() -> any UserRepository {
		LiveUserRepository()
	}
}

let graph = AppGraph.override(
	userRepository: .replace {
		StubUserRepository()
	}
).build()
```

`OverrideBuilder`는 교체 Factory와 `.original` 선택만 보관합니다. graph와 shared 등록은 `.build()`를 호출할 때 처음 만들며, 같은 builder로 여러 번 `.build()`하면 서로 다른 graph와 shared 저장소를 얻습니다. shared 교체 Factory는 graph마다 한 번 실행하고, transient 교체 Factory는 생성 프로퍼티를 읽을 때마다 실행합니다.

builder를 보관하는 동안에는 builder가 선택한 모든 교체 Factory와 capture를 보관합니다. `.build()` 뒤 graph는 transient 교체 Factory와 그 capture만 graph가 해제될 때까지 보관합니다. shared 교체 Factory는 결과를 만든 뒤 graph에 보관하지 않습니다. 따라서 Factory가 graph 또는 builder를 capture하면 참조 순환이 생기지 않도록 수명을 직접 확인해야 합니다.

`.replace` closure의 매개변수 타입·순서·반환 타입은 원래 `@Provide` Factory와 같습니다. 잘못된 매개변수 또는 반환 타입, 존재하지 않거나 중복한 argument label은 Swift 컴파일러가 closure 또는 호출 원본 위치에서 오류를 표시합니다. `Optional`, `Any`, 문자열 key, 전역 등록소는 교체 경로에 사용하지 않습니다.

`sources` graph에서는 조합 graph가 직접 선언한 등록만 교체합니다. source graph 내부 등록은 전파해 교체하지 않으며 `.build(...)`에 source graph를 전달합니다. source graph를 함께 교체해야 하면 그 graph의 `override`를 별도로 호출합니다.

## actor graph

`@DependencyGraph`는 비 generic actor에도 적용할 수 있습니다. actor graph에서 만든 생성 프로퍼티는 actor-isolated 상태로 남으므로 actor 밖에서는 `await`로 읽습니다. shared 등록은 class graph와 마찬가지로 graph 인스턴스별 타입 지정 `let` 저장소에 한 번 만들고, transient 등록은 접근할 때마다 Factory를 다시 호출합니다.

```swift
import Cradle

struct UserSession: Sendable {
	let token: String
}

@DependencyGraph
actor SessionGraph {
	@Provide(.shared)
	private func makeUserSession() -> UserSession {
		UserSession(token: "token")
	}
}

func loadSession() async -> UserSession {
	let graph = SessionGraph()
	return await graph.userSession
}
```

actor 내부에서는 non-`Sendable` 등록을 사용할 수 있습니다. 반면 actor 밖에서 non-`Sendable` 생성 프로퍼티를 `await`로 읽으면 Swift 컴파일러가 그 소비 위치에서 오류를 표시합니다. Macro는 `Sendable` 준수나 actor 경계 통과 여부를 판단하지 않습니다.

actor graph에는 `sources`를 지정할 수 없습니다. actor source graph 조합, `async`·`throws`·`rethrows` Factory, `nonisolated`, `nonisolated(unsafe)`, `@unchecked Sendable`, lock은 지원하지 않습니다.

actor graph에 `overrides: true`를 지정하면 교체 Factory는 `@Sendable` closure여야 하고 `OverrideBuilder`도 `Sendable`을 준수합니다. non-`Sendable` 값을 capture하면 Swift 컴파일러가 closure 원본 위치에서 오류를 표시합니다. `@MainActor` graph의 `override`와 `OverrideBuilder.build()`는 `@MainActor` 격리를 유지합니다.

## class graph 동시성

`final class` graph는 동시 접근을 조정하지 않습니다. 여러 Task에서 graph를 공유해야 하면 단일 소유자로 사용하거나 `@MainActor`처럼 명시한 전역 actor 격리 안에 둡니다. Macro는 class graph를 동시 접근에 안전하게 만들 lock이나 `@unchecked Sendable`을 생성하지 않습니다.

## source graph 조합

`sources`는 `final class` 조합 graph에서만 사용할 수 있습니다. 조합 graph가 직접 읽을 source graph type을 `GraphType.self` 배열로 지정합니다. Macro는 source type의 마지막 식별자를 lowerCamelCase로 바꾼 `private let` 저장 프로퍼티와 graph 접근 수준의 initializer를 만듭니다. 조합 Factory 본문에서는 이 저장 프로퍼티로 source graph의 생성 프로퍼티를 직접 읽습니다.

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

@DependencyGraph(sources: [SessionGraph.self, AppGraph.self], overrides: true)
final class FeatureGraph {
	@Provide
	private func makeFeature() -> Feature {
		Feature(
			repository: appGraph.repository,
			session: sessionGraph.session
		)
	}
}

let graph = FeatureGraph.override(
	feature: .replace {
		Feature(repository: Repository(), session: Session())
	}
).build(appGraph: AppGraph(), sessionGraph: SessionGraph())
let feature = graph.feature
```

`sources` 배열의 순서는 의미가 없습니다. Macro는 source type의 정규화한 이름순으로 저장 프로퍼티와 initializer 매개변수를 생성하므로, 위 예시의 initializer 매개변수도 `appGraph`, `sessionGraph` 순서입니다. 같은 source type을 중복하거나 서로 같은 저장 프로퍼티 이름을 만들면 오류를 냅니다.

조합 graph는 source graph를 강하게 보관합니다. source graph의 shared 생성 프로퍼티는 source graph마다 같은 값을 반환합니다. 조합 graph의 transient Factory는 source graph의 transient 생성 프로퍼티를 읽을 때마다 source Factory를 다시 호출합니다.

조합 graph의 shared Factory도 source graph 생성 프로퍼티를 본문에서 직접 읽을 수 있습니다. Macro는 source 저장 프로퍼티를 먼저 대입한 뒤 실제로 참조한 source graph만 shared 저장소 생성기에 전달합니다. source graph의 transient 생성 프로퍼티는 이 생성기가 graph 초기화 중 실행될 때 평가되고, 결과는 조합 graph의 shared 값에 보관됩니다. source 생성 프로퍼티가 없거나 접근 수준이 맞지 않거나 반환 타입이 맞지 않으면 Macro가 대신 연결하지 않으며 Swift 컴파일러가 원본 Factory 본문에서 오류를 표시합니다.

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

## 호출 시점 외부 입력

화면 식별자처럼 graph를 만들 때 정할 수 없는 값은 `@External`로 표시합니다. 이름 충돌을 피해야 할 때는 `@Cradle.External`로 한정할 수 있습니다. 두 표기는 명시적인 `@Provide(.transient)` Factory 매개변수에서만 사용할 수 있습니다. Macro는 표시하지 않은 매개변수를 타입으로 graph 등록에 연결하고, 표시한 매개변수만 받는 생성 메서드를 만듭니다.

```swift
import Cradle

struct UserID {
	let rawValue: Int
}

final class UserRepository {}

final class UserProfileViewModel {
	let repository: UserRepository
	let id: UserID

	init(repository: UserRepository, id: UserID) {
		self.repository = repository
		self.id = id
	}
}

@DependencyGraph(overrides: true)
final class AppGraph {
	@Provide
	private func makeUserRepository() -> UserRepository {
		UserRepository()
	}

	@Provide(.transient)
	private func makeUserProfileViewModel(
		repository: UserRepository,
		@External id: UserID
	) -> UserProfileViewModel {
		UserProfileViewModel(repository: repository, id: id)
	}
}

let graph = AppGraph.override().build()
let viewModel = graph.userProfileViewModel(id: UserID(rawValue: 29))
```

이 예시에서 `UserRepository`는 graph가 전달하고 `UserID`는 생성 메서드 호출자가 전달합니다. 생성 메서드 이름은 반환 타입을 lowerCamelCase로 바꾼 `userProfileViewModel`입니다. 외부 인자 레이블, 지역 이름, 타입과 선언 순서는 생성 메서드와 원본 Factory 호출에 유지됩니다. `@External _ id: UserID`처럼 `_` 외부 레이블도 사용할 수 있습니다.

생성 메서드는 호출할 때마다 Factory를 실행하며 graph는 결과를 보관하지 않습니다. 같은 입력을 반복해서 전달해도 Factory가 같은 인스턴스나 값을 반환하는지는 보장하지 않습니다. `External<Value>` wrapper도 생성 메서드 서명이나 반환 결과에 노출하거나 저장하지 않습니다.

본문 없는 Factory에서도 같은 규칙을 사용합니다. Macro는 graph 의존성과 외부 입력을 원래 선언 순서대로 반환 타입 initializer에 전달하고, 생성 메서드는 외부 입력만 받습니다.

외부 입력이 있는 Factory의 반환 타입은 일반 graph 등록이 아닙니다. 따라서 생성 프로퍼티, shared 저장소, 자동 의존성 연결과 순환 검사 간선에 포함되지 않습니다. 다른 Factory가 이 반환 타입을 매개변수로 요구하면 Macro는 생성 메서드를 직접 호출해야 한다는 오류를 표시합니다. 등록이 빠진 매개변수를 외부 입력으로 추론하지도 않습니다.

`overrides: true` graph에서 `.original`은 원본 Factory를 사용합니다. `.replace` Factory는 graph 의존성과 외부 입력을 포함한 원래 매개변수 타입과 순서를 모두 유지하며, 외부 입력은 생성 메서드를 호출할 때 전달합니다.

```swift
let graph = AppGraph.override(
	userProfileViewModel: .replace { repository, id in
		UserProfileViewModel(repository: repository, id: id)
	}
).build()

let viewModel = graph.userProfileViewModel(id: UserID(rawValue: 30))
```

actor graph의 생성 메서드는 actor 격리를 유지하므로 actor 밖에서 `await`로 호출합니다. 입력과 반환 값의 `Sendable` 경계, actor override Factory의 non-`Sendable` capture는 Swift 컴파일러가 검사합니다. `@MainActor` graph의 생성 메서드는 같은 `@MainActor` 격리를 따릅니다.

`@External` 매개변수에는 직접 작성한 Optional, 기본값, 가변 인자, `inout`, `@autoclosure`, `some`, `_` 지역 이름을 사용할 수 없습니다. 같은 매개변수에 다른 property wrapper를 함께 붙여도 오류가 발생합니다. 생성 메서드 이름이 기존 인스턴스 프로퍼티·메서드 또는 다른 생성 멤버와 겹쳐도 오류가 발생합니다. `public` graph에서 입력과 반환 타입이 공개되지 않았다면 Swift 컴파일러가 생성 메서드 선언을 거부합니다.

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

## shared 수명과 transient 수명

`@Provide`와 `@Provide(.shared)`는 graph를 만들 때 Factory 결과를 한 번 생성하고, graph 전용의 타입 지정 `let` 저장소가 이를 보유하게 합니다. 같은 graph에서 해당 생성 프로퍼티를 여러 번 읽으면 같은 값을 반환합니다. graph가 해제되면 저장소가 보유한 참조도 함께 놓습니다. 이 수명은 전역 싱글턴이 아니라 graph 인스턴스별 수명입니다.

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

프로퍼티를 읽을 때마다 Factory를 호출해야 하면 `@Provide(.transient)`를 사용합니다. transient Factory는 shared와 transient 등록을 매개변수로 받을 수 있습니다.

shared 수명의 Factory는 다른 shared 등록만 매개변수로 받을 수 있습니다. shared 수명의 Factory가 transient 등록을 받으면 그 transient 값이 graph 생성 때 한 번 만들어져 shared 값에 고정되므로, Macro는 해당 매개변수 타입 위치에 오류를 표시합니다.

shared Factory 본문은 사용자가 작성한 initializer 본문보다 먼저 실행됩니다. 따라서 `self`, `super`, class·actor graph 인스턴스 멤버, 다른 Factory를 직접 참조할 수 없습니다. 필요한 shared 의존성은 Factory 매개변수로 선언합니다. actor graph의 shared Factory가 actor 상태를 읽으면 static helper에서 Swift 컴파일러가 오류를 표시합니다.

source graph 저장 프로퍼티는 shared Factory에서 직접 읽을 수 있습니다. Macro는 이 참조를 생성한 static helper의 매개변수로 바꾸고, source 저장 프로퍼티를 대입한 뒤 helper를 실행합니다. source graph의 transient 값을 읽으면 그 표현식은 조합 graph를 초기화할 때 한 번 평가되어 shared 결과에 보관됩니다.

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

`@DependencyGraph`는 제네릭 매개변수와 제네릭 `where` 절이 없는 `final class` 또는 actor에 적용합니다. `sources`는 `final class`에만 지정할 수 있습니다. `@Provide` Factory는 graph 본체에 직접 선언한 동기 `private` 인스턴스 메서드여야 하며, 명시적 반환 타입이 필요합니다.

`@Provide` 매개변수에는 기본값, 가변 인자, `inout`, `@autoclosure`, `some`, `_` 지역 이름을 사용할 수 없습니다. `async`, `throws`, `rethrows`, 함수 제네릭, 타입 메서드도 사용할 수 없습니다.

Factory 반환 타입과 매개변수 타입에는 직접 작성한 Optional을 사용할 수 없습니다. `Service?`, `Optional<Service>`, `Swift.Optional<Service>`가 여기에 포함됩니다. Macro는 Optional을 대체할 `nil` 경로를 만들지 않습니다.

반환 타입은 프로퍼티 이름을 만들 수 있는 명목 타입 또는 `any`를 사용한 단일 protocol 타입이어야 합니다. `Array<Service>`와 `Dictionary<Key, Value>`처럼 이름으로 작성한 제네릭 명목 타입은 사용할 수 있지만, `[Service]`, `[Key: Value]` 축약 문법은 지원하지 않습니다. 함수, 튜플, 메타타입, `some` 타입, protocol 조합도 등록 타입으로 지원하지 않습니다. `typealias`가 가리키는 실제 타입은 분석하지 않습니다.

유효한 graph에서는 누락 등록, 중복 등록, 기존 멤버 충돌, shared → transient 참조, 순환 의존성을 컴파일 중 진단합니다. 이런 오류가 있으면 관련 없는 등록을 포함해 graph 프로퍼티를 생성하지 않습니다.

## 접근 수준과 초기화

생성 프로퍼티는 graph와 같은 접근 수준을 가집니다. `overrides: true` graph는 `override`, `OverrideBuilder`, `build()`도 graph와 같은 접근 수준으로 생성합니다. `public` graph에서 교체 Factory의 매개변수·반환 타입과 source graph 인자는 외부 모듈에서 접근할 수 있어야 합니다.

`sources`와 `overrides: true`를 모두 지정하지 않은 graph에서는 Macro가 생성자를 추가하지 않으며 사용자가 선언한 생성자와 인스턴스 저장 프로퍼티를 바꾸지 않습니다. `sources` graph와 `overrides: true` graph는 Macro가 생성 경로를 소유합니다. 이 graph에서는 사용자가 initializer를 직접 선언하거나 Swift가 자동 초기화하지 않는 인스턴스 저장 프로퍼티를 선언하면 오류를 냅니다. Optional `var`와 기본 initializer가 있는 property wrapper 저장 프로퍼티는 Swift의 자동 초기화를 사용합니다.

`sources` graph가 protocol만 채택하면 생성 initializer가 그대로 protocol 채택을 유지합니다. superclass를 상속한 `sources` graph에는 Macro가 `super.init()`을 생성하지 않습니다. superclass initializer 호출이 필요하면 Swift 컴파일러가 생성 initializer에서 오류를 표시합니다.

## 현재 지원 범위

현재 `@DependencyGraph`는 동기 Factory의 타입 기반 연결, transient·shared 수명, 호출 시점 외부 입력 생성 메서드, graph 인스턴스별 Factory 교체를 지원합니다. 다음 기능은 아직 지원하지 않습니다.

- graph 생성 뒤 등록 교체
- source graph 생성 프로퍼티의 자동 주입
- qualifier와 multibinding
- graph 생성자 입력
- actor graph의 `sources`와 actor source graph 조합
- `async`, `throws`, `rethrows` Factory
- `nonisolated`, `nonisolated(unsafe)`, `@unchecked Sendable`, lock
- 구체 구현 타입 자동 탐색
