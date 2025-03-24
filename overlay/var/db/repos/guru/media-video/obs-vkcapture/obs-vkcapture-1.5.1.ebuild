# Copyright 1999-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

CMAKE_REMOVE_MODULES_LIST=( FindFreetype )

inherit xdg cmake-multilib

if [[ ${PV} == 9999 ]]; then
	inherit git-r3
	EGIT_REPO_URI="https://github.com/nowrep/obs-vkcapture"
else
	SRC_URI="https://github.com/nowrep/obs-vkcapture/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz"
	KEYWORDS="~amd64"
fi

DESCRIPTION="OBS Linux Vulkan/OpenGL game capture"
HOMEPAGE="https://github.com/nowrep/obs-vkcapture"

LICENSE="GPL-2"
SLOT="0"

COMMON_DEPEND="
	dev-libs/wayland
	media-libs/libglvnd[${MULTILIB_USEDEP}]
	media-libs/vulkan-loader[${MULTILIB_USEDEP}]
	media-video/obs-studio[wayland]
	x11-libs/libxcb[${MULTILIB_USEDEP}]
"
DEPEND="
	${COMMON_DEPEND}
	dev-util/vulkan-headers
	dev-util/wayland-scanner
"

RDEPEND="${COMMON_DEPEND}"

QA_SONAME="
	/usr/lib64/libVkLayer_obs_vkcapture.so
	/usr/lib64/libobs_glcapture.so
	/usr/lib/libVkLayer_obs_vkcapture.so
	/usr/lib/libobs_glcapture.so
"

src_unpack() {
	default

	if [[ ${PV} == 9999 ]]; then
		git-r3_src_unpack
	fi
}

multilib_src_configure() {
if ! multilib_is_native_abi; then
	local mycmakeargs+=(
	-DBUILD_PLUGIN=OFF
	)
fi
	cmake_src_configure
}
