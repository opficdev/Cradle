//
//  WorkspaceDiagramRequest.swift
//  CradleDiagramMakerSupport
//
//  Created by opfic on 9/8/26.
//

import Foundation

// workspace Mermaid 출력 보기
package enum WorkspaceDiagramView: String, Codable {
	// 선언 관계만 표시하는 보기
	case declarations
	// 실제 조립 경로를 표시하는 보기
	case composition
}

// workspace Mermaid 생성 요청
package struct WorkspaceDiagramRequest {
	// workspace manifest 파일
	package let manifestURL: URL
	// 산출물 상위 디렉터리
	package let outputDirectoryURL: URL
	// 생성할 Mermaid 보기
	package let view: WorkspaceDiagramView

	package init(manifestURL: URL, outputDirectoryURL: URL, view: WorkspaceDiagramView) {
		self.manifestURL = manifestURL
		self.outputDirectoryURL = outputDirectoryURL
		self.view = view
	}
}
