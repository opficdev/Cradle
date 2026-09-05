#!/bin/bash
set -euo pipefail

# Git URL 기반 Cradle과 CradlePlugin 소비자 build 검증
if [[ "$#" -ne 3 ]]; then
	echo "Usage: $0 <revision|exact> <reference> <expected-revision>" >&2
	exit 1
fi

mode="$1"
reference="$2"
expected_revision="$3"
if [[ ! "$expected_revision" =~ ^[0-9a-f]{40}$ ]]; then
	echo "Expected revision must be a 40-character commit hash" >&2
	exit 1
fi

case "$mode" in
	revision)
		if [[ ! "$reference" =~ ^[0-9a-f]{40}$ ]]; then
			echo "Revision must be a 40-character commit hash" >&2
			exit 1
		fi
		;;
	exact)
		if [[ ! "$reference" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
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

resolved="$fixture/Package.resolved"
if [[ ! -f "$resolved" ]]; then
	echo "Missing resolved package state" >&2
	exit 1
fi

resolved_revision="$(ruby -rjson -e '
	resolved = JSON.parse(File.read(ARGV.fetch(0)))
	pin = resolved.fetch("pins").find { |candidate| candidate.fetch("identity") == "cradle" }
	abort "Missing Cradle resolved package" if pin.nil?
	print pin.fetch("state").fetch("revision")
' "$resolved")"
if [[ "$resolved_revision" != "$expected_revision" ]]; then
	echo "Resolved revision does not match expected revision" >&2
	exit 1
fi

if [[ "$mode" == "exact" ]]; then
	resolved_version="$(ruby -rjson -e '
		resolved = JSON.parse(File.read(ARGV.fetch(0)))
		pin = resolved.fetch("pins").find { |candidate| candidate.fetch("identity") == "cradle" }
		abort "Missing Cradle resolved package" if pin.nil?
		print pin.fetch("state").fetch("version")
	' "$resolved")"
	if [[ "$resolved_version" != "$reference" ]]; then
		echo "Resolved version does not match requested version" >&2
		exit 1
	fi
fi

echo "Cradle consumer build and resolved revision verification succeeded for $mode $reference"
