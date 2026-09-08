# 여러 모듈 workspace Mermaid

`CradlePlugin`은 한 target 안의 선언을 그립니다. 여러 모듈의 `GraphSet`과 `Graph(input:)` 전달 경로는 `CradleDiagramMaker`의 workspace 명령으로 분석합니다.

## 준비

workspace manifest에는 실제 target ID, `moduleName`, source 파일, 로컬 target dependency를 적습니다. Tuist 설정을 자동으로 읽지 않으므로 target의 실제 source membership을 기준으로 작성합니다.

```json
{
	"schemaVersion": 1,
	"workspaceName": "App",
	"rootDirectory": ".",
	"targets": [
		{"id":"Infra","moduleName":"Infra","sourceFiles":["Sources/Infra/ServiceGraph.swift"],"dependencies":[]},
		{"id":"App","moduleName":"App","sourceFiles":["Sources/App/AppGraph.swift"],"dependencies":["Infra"]}
	],
	"roots": [{"targetID":"App","graph":"AppGraph"}],
	"compositionTypes": [{"targetID":"App","type":"InfraGraphSet"}]
}
```

`target ID`와 `moduleName`은 같을 필요가 없습니다. `sourceFiles`에는 test, 예제, 생성하지 않은 source를 섞지 않습니다.

## 실행

준비한 host architecture용 artifact 경로와 manifest를 명시해 실행합니다.

```sh
bash Scripts/GenerateWorkspaceDiagram.sh \
	--tool /path/to/CradleDiagramMaker \
	--manifest Scripts/Cradle/workspace.json \
	--output .cradle/diagrams
```

script의 기본 view는 `composition`입니다. 선언 관계만 보려면 `--view declarations`를 추가합니다.

`declarations`는 target과 `sources` 선언 관계를 보여줍니다. `composition`은 root에서 시작해 `GraphSet` initializer와 `Graph(input:)`에 실제로 전달한 provider 출처를 연결합니다. 생성 결과는 `.mmd`와 `.analysis.json`으로 저장합니다.

## 지원 범위

일반 조립 객체는 manifest의 `compositionTypes`에 명시한 타입만 분석합니다. 직접 `let` 저장 프로퍼티, 단순 initializer 대입, `Graph(input:)` 생성만 추적합니다. `lazy var`, computed property, property wrapper, 분기, 반복, IIFE, helper 함수 호출, input 전체 전달은 연결을 추정하지 않고 analysis report에 경고로 남깁니다.

분석기는 앱을 실행하지 않습니다. 모든 `#if` 절을 수집하며, Tuist 명령이나 `Project.swift`를 자동으로 변환하지 않습니다.
