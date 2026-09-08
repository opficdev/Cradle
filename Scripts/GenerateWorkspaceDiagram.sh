#!/bin/bash
set -euo pipefail

# 준비된 workspace Mermaid 도구를 manifest 입력으로 실행
tool=""
manifest=""
output=""
view="composition"

while [[ "$#" -gt 0 ]]; do
	case "$1" in
		--tool)
			tool="${2:-}"
			shift 2
			;;
		--manifest)
			manifest="${2:-}"
			shift 2
			;;
		--output)
			output="${2:-}"
			shift 2
			;;
		--view)
			view="${2:-}"
			shift 2
			;;
		*)
			echo "Usage: $0 --tool <path> --manifest <path> --output <directory> [--view declarations|composition]" >&2
			exit 1
			;;
	esac
done

if [[ -z "$tool" || -z "$manifest" || -z "$output" ]]; then
	echo "Usage: $0 --tool <path> --manifest <path> --output <directory> [--view declarations|composition]" >&2
	exit 1
fi

if [[ ! -x "$tool" ]]; then
	echo "CradleDiagramMaker 실행 파일을 찾을 수 없습니다: $tool" >&2
	exit 1
fi

if [[ ! -r "$manifest" ]]; then
	echo "workspace manifest를 읽을 수 없습니다: $manifest" >&2
	exit 1
fi

case "$view" in
	declarations | composition)
		;;
	*)
		echo "workspace view는 declarations 또는 composition이어야 합니다: $view" >&2
		exit 1
		;;
esac

exec "$tool" --workspace "$manifest" --output "$output" --view "$view"
