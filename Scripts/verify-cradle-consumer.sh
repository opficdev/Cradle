#!/bin/bash
set -euo pipefail

# Git URL 기반 Cradle과 CradlePlugin 소비자 build 검증
if [[ "$#" -ne 2 ]]; then
	echo "Usage: $0 <revision|exact> <reference>" >&2
	exit 1
fi

mode="$1"
reference="$2"
case "$mode" in
	revision)
		if [[ ! "$reference" =~ ^[0-9a-f]{40}$ ]]; then
			echo "Revision must be a 40-character commit hash" >&2
			exit 1
		fi
		;;
	exact)
		if [[ ! "$reference" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
			echo "Version must use semantic versioning like 1.0.0" >&2
			exit 1
		fi
		;;
	*)
		echo "Unsupported dependency mode: $mode" >&2
		exit 1
		;;
esac

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
temporary="$(mktemp -d "${TMPDIR:-/tmp}/cradle-consumer.XXXXXX")"
trap 'rm -rf "$temporary"' EXIT
fixture="$temporary/CradlePluginConsumer"
manifest="$fixture/Package.swift"

cp -R "$repo_dir/Tests/IntegrationFixtures/CradlePluginConsumer" "$fixture"

CRADLE_DEPENDENCY_MODE="$mode" CRADLE_DEPENDENCY_REFERENCE="$reference" perl -0pi -e '
	my $mode = $ENV{CRADLE_DEPENDENCY_MODE};
	my $reference = $ENV{CRADLE_DEPENDENCY_REFERENCE};
	my $replacement = qq{.package(url: "https://github.com/opficdev/Cradle.git", $mode: "$reference")};
	my $count = s{\.package\(path: "\.\./\.\./\.\."\)}{$replacement};
	die "Unable to replace local Cradle dependency\n" unless $count == 1;
' "$manifest"

swift build \
	--package-path "$fixture" \
	--scratch-path "$temporary/scratch"

echo "Cradle consumer build succeeded for $mode $reference"
