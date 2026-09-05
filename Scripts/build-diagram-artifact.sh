#!/bin/bash
set -euo pipefail

# 저장소에 포함할 두 macOS host용 Maker 생성
repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_dir"
for architecture in arm64 x86_64; do
	swift build -c release --product CradleDiagramMakerSource --arch "$architecture"
	bin_dir="$(swift build -c release --arch "$architecture" --show-bin-path)"
	artifact="Artifacts/CradleDiagramMaker.artifactbundle/CradleDiagramMaker-$architecture/bin/CradleDiagramMaker"
	mkdir -p "$(dirname "$artifact")"
	install -m 755 "$bin_dir/CradleDiagramMakerSource" "$artifact"
	file "$artifact"
done
