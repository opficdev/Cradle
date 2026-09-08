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

## 조립 관계 읽기

`composition`은 분석한 일반 조립 객체도 module 안에 표시합니다. 타입 이름이 `GraphSet`인지, 폴더가 특정 계층 이름인지로 역할을 정하지 않습니다. manifest에 지정한 타입과 지원되는 실제 구문을 사용합니다.

| 표시 | 방향과 의미 |
| --- | --- |
| 실선 | provider에서 사용하는 값의 provider 또는 input으로 향하는 의존 관계 |
| 점선 `반환` | Factory에서 반환식으로 확인된 객체로 향하는 관계 |
| 점선 `생성` | 조립 객체에서 저장 멤버 우변의 직접 생성자로 만든 객체 또는 graph로 향하는 관계 |
| 점선 `보관` | 조립 객체에서 매개변수나 멤버 참조를 통해 전달받아 저장한 기존 객체 또는 graph로 향하는 관계 |

예를 들어 `Factory → Container → WorkerGraph`는 Factory가 Container를 반환하고, Container가 WorkerGraph를 직접 생성한 경로를 나타냅니다. `self.worker = existingWorker`는 기존 WorkerGraph를 보관하는 관계입니다. 같은 타입을 두 번 생성하면 서로 다른 node로 표시하며, 같은 값을 두 번 저장하면 하나의 대상을 가리키고 각각의 근거 위치를 report에 남깁니다.

점선은 정적으로 확인한 조립 관계이며 실행 순서나 runtime 수명을 보장하지 않습니다. 일반 provider 결과나 미해석 값의 내부 객체를 추가로 추정하지 않습니다. manifest에서 빠진 source의 내부까지 연결되지 않으므로 일부 파일만 넣으면 부분적인 그림이 생성됩니다.

workspace `.analysis.json`의 `schemaVersion`은 **2**입니다. `compositionObject` node와 `compositionReturn`, `compositionCreation`, `compositionRetention` edge가 추가됐습니다. 각 edge의 `evidence`에는 반환식 또는 저장 우변의 상대 파일 경로와 UTF-8 offset이 기록됩니다. 입력 manifest의 `schemaVersion`은 기존 **1**을 유지합니다.

## 지원 범위

일반 조립 객체는 manifest의 `compositionTypes`에 명시한 타입만 분석합니다. 직접 `let` 저장 프로퍼티, 단순 initializer 대입, `Graph(input:)` 생성만 추적합니다. `lazy var`, computed property, property wrapper, 분기, 반복, IIFE, helper 함수 호출, input 전체 전달은 연결을 추정하지 않고 analysis report에 경고로 남깁니다.

분석기는 앱을 실행하지 않습니다. 모든 `#if` 절을 수집하며, Tuist 명령이나 `Project.swift`를 자동으로 변환하지 않습니다.
