#!/bin/sh

set -eu

search_root="${OBJROOT}/BuildToolPluginIntermediates"
destination_directory="${SRCROOT}/.cradle"
destination="${destination_directory}/DependencyGraph.mmd"
matches="${TARGET_TEMP_DIR}/cradle-diagram-paths.txt"
temporary=""

cleanup() {
	/bin/rm -f "${matches}"

	if [ -n "${temporary}" ]; then
		/bin/rm -f "${temporary}"
	fi
}

trap cleanup EXIT

: > "${matches}"

if [ -d "${search_root}" ]; then
	if ! /usr/bin/find "${search_root}" \
		-type f \
		! -type l \
		-path "*/${TARGET_NAME}/CradlePlugin/CradleDiagrams/${TARGET_NAME}/DependencyGraph.mmd" \
		-print > "${matches}"; then
		echo "warning: Cradle DependencyGraph.mmd를 찾지 못해 기존 파일을 유지합니다."
		exit 0
	fi
fi

count=$(/usr/bin/wc -l < "${matches}" | /usr/bin/tr -d ' ')

if [ "${count}" -ne 1 ]; then
	echo "warning: Cradle DependencyGraph.mmd 후보를 하나로 결정하지 못해 기존 파일을 유지합니다."
	exit 0
fi

source_path=$(/usr/bin/sed -n '1p' "${matches}")

if [ ! -f "${source_path}" ] || [ -L "${source_path}" ]; then
	echo "warning: Cradle DependencyGraph.mmd가 없어 기존 파일을 유지합니다."
	exit 0
fi

if [ -L "${destination_directory}" ] || { [ -e "${destination_directory}" ] && [ ! -d "${destination_directory}" ]; }; then
	echo "warning: .cradle 경로를 안전하게 쓸 수 없어 기존 파일을 유지합니다."
	exit 0
fi

if [ -L "${destination}" ] || { [ -e "${destination}" ] && [ ! -f "${destination}" ]; }; then
	echo "warning: DependencyGraph.mmd 경로를 안전하게 쓸 수 없어 기존 파일을 유지합니다."
	exit 0
fi

if ! /bin/mkdir -p "${destination_directory}"; then
	echo "warning: .cradle 디렉터리를 만들지 못해 기존 파일을 유지합니다."
	exit 0
fi

if [ -f "${destination}" ] && /usr/bin/cmp -s "${source_path}" "${destination}"; then
	exit 0
fi

if ! temporary=$(/usr/bin/mktemp "${destination_directory}/.DependencyGraph.mmd.XXXXXX"); then
	echo "warning: Cradle DependencyGraph.mmd 임시 파일을 만들지 못해 기존 파일을 유지합니다."
	exit 0
fi

if ! /bin/cp "${source_path}" "${temporary}"; then
	echo "warning: Cradle DependencyGraph.mmd 복사에 실패해 기존 파일을 유지합니다."
	exit 0
fi

if ! /bin/mv -f "${temporary}" "${destination}"; then
	echo "warning: Cradle DependencyGraph.mmd 반영에 실패해 기존 파일을 유지합니다."
	exit 0
fi
