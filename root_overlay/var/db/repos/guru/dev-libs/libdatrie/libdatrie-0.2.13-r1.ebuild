# Copyright 1999-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit autotools

DESCRIPTION="Double-Array Trie Library"
HOMEPAGE="https://github.com/tlwg/libdatrie"

if [[ ${PV} == "9999" ]] ; then
	inherit git-r3
	EGIT_REPO_URI="https://github.com/tlwg/${PN}.git"
else
	SRC_URI="https://github.com/tlwg/${PN}/archive/v${PV}.tar.gz -> ${P}.tar.gz"
	KEYWORDS="~amd64 ~arm ~arm64 ~riscv ~x86"
fi

LICENSE="LGPL-2.1+"
SLOT="0"
IUSE="doc"

BDEPEND="doc? ( app-text/doxygen )"

src_prepare() {
	default
	# Fixed version if in non git project
	echo ${PV} > VERSION
	eautoreconf
}

src_configure() {
	econf \
		$(use_enable doc doxygen-doc) \
		--with-html-docdir="${EPREFIX}"/usr/share/doc/${PF}/html
}

src_install() {
	default
	find "${ED}" -name '*.la' -delete || die
}
