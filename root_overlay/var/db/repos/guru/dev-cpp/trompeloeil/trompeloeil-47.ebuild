# Copyright 2023-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake

DESCRIPTION="Header only C++14 mocking framework"
HOMEPAGE="https://github.com/rollbear/trompeloeil"
SRC_URI="https://github.com/rollbear/trompeloeil/archive/v${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="Boost-1.0"
SLOT="0"
KEYWORDS="~amd64"
IUSE="test"
RESTRICT="!test? ( test )"

BDEPEND="test? ( >=dev-cpp/catch-2:0 )"

src_prepare() {
	# bug #947154
	sed -i '/-Werror/d' test/CMakeLists.txt || die
	cmake_src_prepare
}

src_configure() {
	local mycmakeargs=(
		-DTROMPELOEIL_BUILD_TESTS=$(usex test)
	)

	cmake_src_configure
}

src_test() {
	cmake_src_test

	"${BUILD_DIR}"/test/self_test || die
}
