#!/bin/bash
set -euo pipefail

# 배포 대상 commit의 Maker source와 artifact 소비 가능 여부 검증
repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
revision="${1:-HEAD}"
temporary="$(mktemp -d "${TMPDIR:-/tmp}/cradle-diagram-artifact.XXXXXX")"
package_dir="$temporary/Cradle"
trap 'rm -rf "$temporary"' EXIT

mkdir -p "$package_dir"
git -C "$repo_dir" archive --format=tar "$revision" | tar -x -C "$package_dir"

artifacts=(
	"Artifacts/CradleDiagramMaker.artifactbundle/CradleDiagramMaker-arm64/bin/CradleDiagramMaker"
	"Artifacts/CradleDiagramMaker.artifactbundle/CradleDiagramMaker-x86_64/bin/CradleDiagramMaker"
)
architectures=(arm64 x86_64)

for index in "${!artifacts[@]}"; do
	artifact="${artifacts[$index]}"
	path="$package_dir/$artifact"
	if [[ ! -x "$path" ]]; then
		echo "Missing executable artifact: $artifact" >&2
		exit 1
	fi
	if ! file "$path" | grep -q "${architectures[$index]}"; then
		echo "Unexpected artifact architecture: $artifact" >&2
		exit 1
	fi
done

host_architecture="$(uname -m)"
case "$host_architecture" in
	arm64 | x86_64)
		;;
	*)
		echo "Unsupported artifact host architecture: $host_architecture" >&2
		exit 1
		;;
esac

stored_tool="$temporary/stored-CradleDiagramMaker"
cp "$package_dir/Artifacts/CradleDiagramMaker.artifactbundle/CradleDiagramMaker-$host_architecture/bin/CradleDiagramMaker" "$stored_tool"

bash "$package_dir/Scripts/build-diagram-artifact.sh"

for index in "${!artifacts[@]}"; do
	artifact="${artifacts[$index]}"
	path="$package_dir/$artifact"
	if [[ ! -x "$path" ]] || ! file "$path" | grep -q "${architectures[$index]}"; then
		echo "Source build did not create expected artifact: $artifact" >&2
		exit 1
	fi
done

fixture="$package_dir/Tests/IntegrationFixtures/CradlePluginConsumer"
scratch="$temporary/consumer-scratch"
source_file="$fixture/Sources/AppComposition/AppGraph.swift"
stored_output="$temporary/stored-output"
source_output="$temporary/source-output"
source_tool="$package_dir/Artifacts/CradleDiagramMaker.artifactbundle/CradleDiagramMaker-$host_architecture/bin/CradleDiagramMaker"

"$stored_tool" --module AppComposition --output "$stored_output" "$source_file"
"$source_tool" --module AppComposition --output "$source_output" "$source_file"

stored_diagram="$stored_output/AppComposition/DependencyGraph.mmd"
source_diagram="$source_output/AppComposition/DependencyGraph.mmd"
if ! cmp -s "$stored_diagram" "$source_diagram"; then
	echo "Committed artifact output does not match source-built artifact" >&2
	exit 1
fi

swift build --package-path "$fixture" --scratch-path "$scratch"

diagram="$(find "$scratch" -name DependencyGraph.mmd -type f -print -quit)"
if [[ -z "$diagram" ]] || ! grep -q "AppGraph" "$diagram" || ! grep -q "ExplicitGraph" "$diagram"; then
	echo "Source-built artifact did not create expected Mermaid output" >&2
	exit 1
fi

echo "CradleDiagramMaker artifacts passed consumer verification for $revision"
