# ``Cradle``

Cradle은 Swift 매크로로 의존 관계를 정적 그래프로 구성하고 각 인스턴스의 생성과 수명을 그래프 단위로 관리하는 Swift 라이브러리입니다.

## Overview

현재는 `@DependencyGraph`를 `final class`에 적용해 그래프를 선언합니다. 그래프 클래스 안에 매개변수가 없는 `private` Factory를 선언하고 `@Provide`를 붙이면 의존성을 등록할 수 있습니다. 매크로는 Factory의 반환 타입을 바탕으로 생성 접근자를 그래프에 추가합니다.

생성 접근자는 Factory를 호출할 뿐 결과를 별도로 저장하거나 재사용하지 않습니다. Factory가 새 값을 반환하도록 구현하면 접근자를 호출할 때마다 새 값을 얻습니다.

매크로는 그래프에 생성자를 추가하지 않으며 사용자가 선언한 생성자와 인스턴스 저장 프로퍼티도 변경하지 않습니다. 그래프를 외부 모듈에서 생성해야 한다면 필요한 생성자를 직접 선언합니다.

## Topics

### 사용 안내

- <doc:DependencyGraph>

### 매크로

- ``DependencyGraph()``
- ``Provide()``
