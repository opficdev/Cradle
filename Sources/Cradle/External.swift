//
//  External.swift
//  Cradle
//
//  Created by opfic on 9/4/26.
//

// graph 생성 메서드 호출자가 전달할 `@Provide(.transient)` 입력
/// `@Provide(.transient)` Factory에 호출 시점 외부 입력을 표시하는 property wrapper입니다.
///
/// graph는 이 값을 등록하거나 생성하지 않습니다. 외부 입력 생성 메서드의 사용 조건은 <doc:DependencyGraph>에서 설명합니다.
@propertyWrapper
public struct External<Value> {
	// 원본 Factory가 사용할 외부 입력
	/// 원본 Factory 매개변수에 전달할 외부 입력 값입니다.
	///
	/// 외부 입력의 생성 경로는 <doc:DependencyGraph>에서 설명합니다.
	public let wrappedValue: Value

	// 생성 메서드에서 받은 값을 원본 Factory 매개변수로 전달
	/// 원본 Factory 매개변수에 전달할 외부 입력 값을 저장합니다.
	///
	/// 외부 입력 생성 메서드의 사용 조건은 <doc:DependencyGraph>에서 설명합니다.
	public init(wrappedValue: Value) {
		self.wrappedValue = wrappedValue
	}
}
