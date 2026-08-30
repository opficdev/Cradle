//
//  CircularDependency.swift
//  Cradle
//
//  Created by opfic on 8/30/26.
//

// 첫 순환의 등록 순서와 순환을 닫는 원본 매개변수 보관
struct CircularDependency {
	// 끝의 반복 등록을 제외한 순환 경로의 descriptor 인덱스
	let providerIndices: [Int]
	// 현재 경로의 등록을 다시 요구하는 매개변수
	let closingParameter: ProviderParameterDescriptor
}

// 현재 경로의 재방문과 탐색이 끝난 등록의 재사용 구분
private enum CircularDependencyVisitState {
	case unvisited
	case active
	case complete
}

// 재귀 호출 대신 등록별 탐색 진행 위치 보관
private struct CircularDependencyTraversalFrame {
	// 현재 탐색하는 등록의 descriptor 인덱스
	let providerIndex: Int
	// 다음에 확인할 Factory 매개변수의 인덱스
	var nextParameterIndex = 0
}

// 중복·누락 검사를 통과한 등록에서 선언·매개변수 순서의 첫 순환 탐색
func firstCircularDependency(in providers: [ProviderDescriptor]) -> CircularDependency? {
	// 기존 생성용 이름 사전과 분리한 등록 인덱스
	let indices = Dictionary(uniqueKeysWithValues: providers.enumerated().map { index, provider in
		(provider.accessorIdentifier, index)
	})
	// 등록마다 현재 탐색 경로 포함 여부와 탐색 완료 여부 보관
	var states = Array(repeating: CircularDependencyVisitState.unvisited, count: providers.count)
	// 탐색 중인 등록이 스택에서 시작하는 위치
	var positions = Array(repeating: 0, count: providers.count)
	// 현재 경로와 각 등록의 다음 매개변수 위치
	var stack: [CircularDependencyTraversalFrame] = []

	for root in providers.indices where states[root] == .unvisited {
		states[root] = .active
		positions[root] = stack.count
		stack.append(CircularDependencyTraversalFrame(providerIndex: root))

		while let frame = stack.last {
			guard frame.nextParameterIndex < providers[frame.providerIndex].parameters.count else {
				states[frame.providerIndex] = .complete
				stack.removeLast()
				continue
			}
			// 원본 위치를 유지한 현재 의존 매개변수
			let parameter = providers[frame.providerIndex].parameters[frame.nextParameterIndex]
			stack[stack.count - 1].nextParameterIndex += 1
			// 선행 누락 검사에서 존재를 확인한 대상 등록
			let target = indices[parameter.localName]!

			switch states[target] {
			case .unvisited:
				states[target] = .active
				positions[target] = stack.count
				stack.append(CircularDependencyTraversalFrame(providerIndex: target))
			case .active:
				return CircularDependency(
					providerIndices: stack[positions[target]...].map(\.providerIndex),
					closingParameter: parameter
				)
			case .complete:
				continue
			}
		}
	}
	return nil
}
