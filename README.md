# Cradle

Cradle은 Swift Macro를 사용해 의존성 graph의 factory를 생성하는 라이브러리입니다.

## Mermaid 개발 산출물

`CradlePlugin`은 build 중 Mermaid 원본을 생성합니다. Xcode에서 바로 열 파일이 필요하면 target의 마지막 Run Script 단계가 `.cradle/DependencyGraph.mmd`로 복사하게 설정할 수 있습니다.

### ExampleApp 설정

`Examples/ExampleApp`의 `Cradle Mermaid copy` 단계는 [CopyCradleMermaid.sh](Examples/ExampleApp/Scripts/CopyCradleMermaid.sh)를 실행합니다. 같은 설정을 추가할 때는 이 단계를 target의 마지막 Build Phase에 두고 Based on dependency analysis를 선택 해제합니다.

```sh
/bin/sh "${SRCROOT}/Scripts/CopyCradleMermaid.sh"
```

`Cmd+B`를 마치면 `Examples/ExampleApp/.cradle/DependencyGraph.mmd`가 생성됩니다. `.cradle/`은 Git에서 제외되며 앱이나 라이브러리 제품에 포함되지 않습니다.

Xcode의 build 도구 작업 경로는 공개된 고정 경로가 아닙니다. 이 설정은 현재 `CradlePlugin` 산출물을 쉽게 열기 위한 방법이므로, Xcode 구조가 바뀐 뒤 경고가 나오면 [CopyCradleMermaid.sh](Examples/ExampleApp/Scripts/CopyCradleMermaid.sh)의 검색 경로를 확인해야 합니다.
