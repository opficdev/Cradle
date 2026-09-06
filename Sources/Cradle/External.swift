//
//  External.swift
//  Cradle
//
//  Created by opfic on 9/4/26.
//

// graph 생성 메서드 호출자가 전달할 `@Provide(.transient)` 입력
/**
 `@Provide(.transient)` Factory에 호출 시점 외부 입력을 표시하는 property wrapper입니다.

 Macro는 `@External` 매개변수만 호출자가 전달하는 생성 메서드를 만들고, 나머지 매개변수는 graph 등록으로
 연결합니다.

 - Important: graph는 이 값을 등록하거나 보관하지 않으며, 명시적인 `.transient` Factory에서만 사용할 수
   있습니다.
 */
@propertyWrapper
public struct External<Value> {
	// 원본 Factory가 사용할 외부 입력
	/**
	 원본 Factory 매개변수에 전달할 외부 입력 값입니다.

	 - Note: 생성된 호출 시점 메서드의 서명이나 반환 결과에는 `External<Value>`가 노출되지 않습니다.
	 */
	public let wrappedValue: Value

	// 생성 메서드에서 받은 값을 원본 Factory 매개변수로 전달
	/**
	 원본 Factory 매개변수에 전달할 외부 입력 값을 저장합니다.

	 - Parameter wrappedValue: 생성된 호출 시점 메서드가 원본 Factory에 전달할 값입니다.
	 - Note: 이 initializer는 Macro가 생성한 Factory 호출 경로에서 wrapper 값을 구성합니다.
	 */
	public init(wrappedValue: Value) {
		self.wrappedValue = wrappedValue
	}
}
