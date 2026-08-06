# Copyright 1999-2025 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
EAPI=8

inherit cmake

DESCRIPTION="CastXML is a C-family abstract syntax tree XML output tool."
HOMEPAGE="https://github.com/CastXML/CastXML"
SRC_URI="https://github.com/CastXML/CastXML/archive/v${PV}.tar.gz"
LICENSE="Apache-2.0"
SLOT="0"
KEYWORDS="~x86 ~amd64"

DEPENDS="dev-libs/glib:2
	dev-libs/libxml2
	llvm-core/llvm:="
RDEPENDS="${DEPENDS}"

src_configure() {
	local mycmakeargs=(
		-DCLANG_LINK_CLANG_DYLIB=ON
	)
	cmake_src_configure
}
