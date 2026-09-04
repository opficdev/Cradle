//
//  External.swift
//  Cradle
//
//  Created by opfic on 9/4/26.
//

// graph 생성 메서드 호출자가 전달할 `@Provide(.transient)` 입력
@propertyWrapper
public struct External<Value> {
	// 원본 Factory가 사용할 외부 입력
	public let wrappedValue: Value

	// 생성 메서드에서 받은 값을 원본 Factory 매개변수로 전달
	public init(wrappedValue: Value) {
		self.wrappedValue = wrappedValue
	}
}
