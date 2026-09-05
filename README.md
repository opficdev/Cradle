<h1 align="center">Cradle</h1>

<p align="center">
  Factory를 선언하면 Cradle이 의존성을 연결하고 graph별 수명을 관리해요.
</p>

<p align="center">
  <a href="Examples/ExampleApp">ExampleApp</a>
  ·
  <a href="Sources/Cradle/Cradle.docc/DependencyGraph.md">사용 안내</a>
  ·
  <a href="Sources/CradleTesting/CradleTesting.docc/CradleTesting.md">테스트</a>
  ·
  <a href="LICENSE">MIT License</a>
</p>

<br />

Cradle은 Swift Macro를 사용해 `@Provide` Factory를 반환 타입과 매개변수 타입으로 연결해요. 어떤 값을 누가 만들고 언제까지 쓸지는 graph마다 정해요.

Swift tools 6.3과 iOS 17 이상 또는 macOS 10.15 이상이 필요해요.

## 첫 graph

이 예제에서는 `UserRepository`와 `LoadUserUseCase`를 graph가 만들고 보관해요. 화면마다 달라지는 `UserID`는 `userProfileViewModel`을 호출할 때 넘겨요.

```swift
import Cradle

struct UserID {
	let rawValue: String
}

struct User {
	let id: UserID
}

protocol UserRepository {
	func load(id: UserID) -> User
}

struct LiveUserRepository: UserRepository {
	func load(id: UserID) -> User {
		User(id: id)
	}
}

struct LoadUserUseCase {
	let repository: any UserRepository

	func execute(id: UserID) -> User {
		repository.load(id: id)
	}
}

struct UserProfileViewModel {
	let user: User
}

@DependencyGraph
final class AppGraph {
	@Provide
	private func makeUserRepository() -> any UserRepository {
		LiveUserRepository()
	}

	@Provide
	private func makeLoadUserUseCase(
		repository: any UserRepository
	) -> LoadUserUseCase {
		LoadUserUseCase(repository: repository)
	}

	@Provide(.transient)
	private func makeUserProfileViewModel(
		useCase: LoadUserUseCase,
		@External userID: UserID
	) -> UserProfileViewModel {
		UserProfileViewModel(user: useCase.execute(id: userID))
	}
}

let graph = AppGraph()
let viewModel = graph.userProfileViewModel(
	userID: UserID(rawValue: "user-1")
)
```

`@Provide`는 반환 타입을 기준으로 Factory를 연결해요. 기본값은 graph마다 한 번 만들고 계속 쓰며, `.transient`는 접근할 때마다 새로 만들어요. `@External`은 graph가 만들 수 없는 호출 시점 값에 붙여요.

Cradle은 graph를 만들 때 누락한 등록, 중복된 등록, 순환 의존성처럼 연결할 수 없는 구성을 컴파일 단계에서 알려줘요. Factory 본문에서 하는 임의 호출이나 실행 중 상태까지 검사하지는 않아요.

## 설치

아직 release tag가 없어요. 지금은 `develop` branch를 가리켜 설치해요.

```swift
dependencies: [
	.package(
		url: "https://github.com/opficdev/Cradle.git",
		branch: "develop"
	)
]
```

Cradle을 쓸 target에는 `Cradle` product를 추가해요.

```swift
.target(
	name: "AppComposition",
	dependencies: [
		.product(name: "Cradle", package: "Cradle")
	]
)
```

<details>
<summary>첫 release tag 뒤 버전을 고정하기</summary>

첫 release tag가 올라오면 의존성 버전을 고정할 수 있어요.

```swift
dependencies: [
	.package(url: "https://github.com/opficdev/Cradle.git", from: "1.0.0")
]
```

</details>

<details>
<summary>테스트와 Mermaid 산출물 추가하기</summary>

테스트에서 Factory를 바꾸려면 `CradleTesting`을 test target에만 연결해요. graph 선언과 `.mock` 편의 API를 함께 쓰려면 `Cradle`도 같은 target에 추가해요.

```swift
.testTarget(
	name: "AppCompositionTests",
	dependencies: [
		.product(name: "Cradle", package: "Cradle"),
		.product(name: "CradleTesting", package: "Cradle")
	]
)
```

`CradlePlugin`은 Swift에서 import하지 않아요. macOS build host에서 실행되는 Build Tool Plugin이므로 Mermaid 개발 산출물이 필요할 때만 target에 연결해요.

```swift
.target(
	name: "AppComposition",
	dependencies: [
		.product(name: "Cradle", package: "Cradle")
	],
	plugins: [
		.plugin(name: "CradlePlugin", package: "Cradle")
	]
)
```

`CradlePlugin`은 arm64 또는 x86_64 macOS build host에서만 쓸 수 있어요.

</details>

<details>
<summary>Xcode에서 Mermaid 파일 열기</summary>

`CradlePlugin`은 build 때 Mermaid 원본을 만들어요. Xcode에서 파일을 바로 열고 싶다면 target의 마지막 Run Script 단계에서 [CopyCradleMermaid.sh](Examples/ExampleApp/Scripts/CopyCradleMermaid.sh)를 실행하고 Based on dependency analysis를 선택 해제해요.

```sh
/bin/sh "${SRCROOT}/Scripts/CopyCradleMermaid.sh"
```

`Cmd+B` 뒤 `Examples/ExampleApp/.cradle/DependencyGraph.mmd`가 생겨요. `.cradle/`은 Git에 올리지 않고 앱과 라이브러리 binary에도 넣지 않아요. Xcode의 build 도구 작업 경로는 공개된 고정 경로가 아니에요. 경고가 나타나면 `CopyCradleMermaid.sh`의 검색 경로를 확인해요.

</details>

<details>
<summary>관리자용 SwiftPM 배포</summary>

관리자는 Actions에서 `Deploy SPM` workflow를 직접 실행해요. 접두사 없는 `version`과 선택 `release_notes`를 입력하면 아래 순서로 배포돼요.

1. `version` 형식과 같은 tag가 이미 있는지 확인해요.
2. artifact, 원격 revision 소비자, 전체 test를 검증해요.
3. 검증한 commit에 annotated tag를 만들고 원격 tag revision을 확인해요.
4. exact version 소비자를 검증한 뒤 GitHub Release를 생성하고 게시 상태를 확인해요.

tag를 원격에 push한 뒤 exact version 소비자 검증이 실패하면 tag는 남지만 GitHub Release는 아직 생성되지 않아요. `createRelease` 요청 뒤 응답 확인이 실패한 경우에는 GitHub에서 Release 생성 여부를 직접 확인해요. 배포 과정에서 tag를 삭제하거나 이동하지 않으므로 원인을 고친 뒤 기존 tag를 기준으로 별도 Release 절차를 진행해요.

</details>

## 더 살펴보기

- [ExampleApp](Examples/ExampleApp) — 단일 app target에서 `sources`, `@External`, SwiftUI `@Observable`과 `@State`를 쓰는 상품 상세 예제
- [DependencyGraph 안내](Sources/Cradle/Cradle.docc/DependencyGraph.md) — `sources`, 수명, actor graph, `CradlePlugin`, 선언 조건과 compiler diagnostic
- [CradleTesting 안내](Sources/CradleTesting/CradleTesting.docc/CradleTesting.md) — `overrides: true`, `.replace`, `.mock`, graph별 테스트 대역 구성
