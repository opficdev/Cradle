# Cradle

Cradle은 Swift Macro를 사용해 의존성 graph의 factory를 생성하는 라이브러리입니다.

## 요구 사항

- Swift tools 6.3
- iOS 17 이상 또는 macOS 10.15 이상
- `CradlePlugin` 사용 시 arm64 또는 x86_64 macOS 빌드 호스트

## 설치

### Swift Package Manager

`Package.swift`의 dependencies에 Cradle을 추가합니다. 아래 `1.0.0`은 배포가 완료된 버전 예시이며, 최초 tag가 게시되기 전에는 실제 설치에 사용할 수 없습니다.

```swift
dependencies: [
	.package(url: "https://github.com/opficdev/Cradle.git", from: "1.0.0")
]
```

앱 또는 라이브러리 target에는 `Cradle` product를 연결합니다.

```swift
.target(
	name: "AppComposition",
	dependencies: [
		.product(name: "Cradle", package: "Cradle")
	]
)
```

`CradleTesting`은 테스트 target에서만 선택적으로 연결합니다. graph 선언과 `.mock` 편의 API를 함께 사용하려면 `Cradle`도 같은 target에 추가합니다.

```swift
.testTarget(
	name: "AppCompositionTests",
	dependencies: [
		.product(name: "Cradle", package: "Cradle"),
		.product(name: "CradleTesting", package: "Cradle")
	]
)
```

`CradlePlugin`은 import하는 라이브러리가 아니라 macOS 빌드 호스트에서 실행하는 Build Tool Plugin입니다. Mermaid 개발 산출물이 필요한 target에만 연결합니다.

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

`@DependencyGraph`, `@Provide`, `@External`의 사용 조건과 생성 멤버 계약은 [DependencyGraph 안내](Sources/Cradle/Cradle.docc/DependencyGraph.md)에서 확인할 수 있습니다. 테스트 대역 교체는 [CradleTesting 안내](Sources/CradleTesting/CradleTesting.docc/CradleTesting.md)를 참고합니다.

## 배포

관리자는 Actions의 `Deploy SPM`을 수동으로 실행하고, 접두사 없는 `version`과 선택 `release_notes`를 입력합니다. 배포 흐름은 다음 순서로 진행합니다.

1. `version` 형식과 기존 tag를 확인합니다.
2. artifact, 원격 revision 소비자, 전체 test를 검증합니다.
3. 검증한 commit에 annotated tag를 만들고 원격 tag revision을 확인합니다.
4. exact version 소비자를 검증한 뒤 GitHub Release를 생성하고 게시 상태를 확인합니다.

tag push 뒤 exact version 소비자 검증이나 Release 생성에 실패하면 tag는 그대로 남고 GitHub Release는 생성되지 않습니다. 배포는 tag를 삭제하거나 이동하지 않으므로, 원인을 확인한 뒤 기존 tag를 기준으로 별도 Release 절차를 진행해야 합니다.

## Mermaid 개발 산출물

`CradlePlugin`은 build 중 Mermaid 원본을 생성합니다. Xcode에서 바로 열 파일이 필요하면 target의 마지막 Run Script 단계가 `.cradle/DependencyGraph.mmd`로 복사하게 설정할 수 있습니다.

### ExampleApp 설정

`Examples/ExampleApp`의 `Cradle Mermaid copy` 단계는 [CopyCradleMermaid.sh](Examples/ExampleApp/Scripts/CopyCradleMermaid.sh)를 실행합니다. 같은 설정을 추가할 때는 이 단계를 target의 마지막 Build Phase에 두고 Based on dependency analysis를 선택 해제합니다.

```sh
/bin/sh "${SRCROOT}/Scripts/CopyCradleMermaid.sh"
```

`Cmd+B`를 마치면 `Examples/ExampleApp/.cradle/DependencyGraph.mmd`가 생성됩니다. `.cradle/`은 Git에서 제외되며 앱이나 라이브러리 제품에 포함되지 않습니다.

Xcode의 build 도구 작업 경로는 공개된 고정 경로가 아닙니다. 이 설정은 현재 `CradlePlugin` 산출물을 쉽게 열기 위한 방법이므로, Xcode 구조가 바뀐 뒤 경고가 나오면 [CopyCradleMermaid.sh](Examples/ExampleApp/Scripts/CopyCradleMermaid.sh)의 검색 경로를 확인해야 합니다.
