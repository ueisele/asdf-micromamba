#!/usr/bin/env bash

set -euo pipefail

GH_REPO="https://github.com/mamba-org/micromamba-releases"
TOOL_CMD="micromamba"

fail() {
	echo -e "asdf-$TOOL_CMD: $*"
	exit 1
}

curl_opts=(-fsSL)

if [ -n "${GITHUB_API_TOKEN:-}" ]; then
	curl_opts=("${curl_opts[@]}" -H "Authorization: token $GITHUB_API_TOKEN")
fi

sort_versions() {
	sed 'h; s/[+-]/./g; s/.p\([[:digit:]]\)/.z\1/; s/$/.z/; G; s/\n/ /' |
		LC_ALL=C sort -t. -k 1,1 -k 2,2n -k 3,3n -k 4,4n -k 5,5n | awk '{print $2}'
}

list_github_tags() {
	git ls-remote --tags --refs "$GH_REPO" |
		grep -o 'refs/tags/.*' | cut -d/ -f3- |
		sed 's/^v//'
}

list_all_versions() {
	list_github_tags
}

get_os() {
	local os="$(uname -o)"
	if [[ "${os}" == "GNU/Linux" ]]; then
		echo "linux"
	elif [[ "${os}" == "Darwin" ]]; then
		echo "osx"
	else
		echo "${os}"
	fi
}

get_platform() {
	local os="$(uname -o)"
	local machine="$(uname -m)"
	if [[ "${os}" == "GNU/Linux" ]]; then
		if [ "${machine}" == "x86_64" ]; then
			echo "linux-64"
		elif [ "${machine}" == "arm64" ]; then
			echo "linux-aarch64"
		else
			echo "linux-${machine}"
		fi
	elif [[ "${os}" == "Darwin" ]]; then
		if [ "${machine}" == "x86_64" ]; then
			echo "osx-64"
		elif [ "${machine}" == "arm64" ]; then
			echo "osx-arm64"
		else
			echo "osx-${machine}"
		fi
	else
		echo "${os}-${machine}"
	fi
}

download_release() {
	local version filename url
	version="$1"
	filename="$2"

	url="$GH_REPO/releases/download/${version}/micromamba-$(get_platform)"

	echo "* Downloading $TOOL_CMD release $version..."
	curl "${curl_opts[@]}" -o "$filename" -C - "$url" || fail "Could not download $url"
}

install_version() {
	local install_type="$1"
	local version="$2"
	local install_path="${3%/bin}/bin"

	if [ "$install_type" != "version" ]; then
		fail "asdf-$TOOL_CMD supports release installs only"
	fi

	(
		mkdir -p "$install_path"
		cp -r "$ASDF_DOWNLOAD_PATH"/* "$install_path"
    chmod +x "$install_path/$TOOL_CMD"

		test -x "$install_path/$TOOL_CMD" || fail "Expected $install_path/$TOOL_CMD to be executable."

		echo "$TOOL_CMD $version installation was successful!"
	) || (
		rm -rf "$install_path"
		fail "An error occurred while installing $TOOL_CMD $version."
	)
}
