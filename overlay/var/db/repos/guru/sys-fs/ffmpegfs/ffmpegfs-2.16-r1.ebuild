# Copyright 1999-2023 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit autotools

DESCRIPTION="FUSE-based transcoding filesystem with support from/to many formats."
HOMEPAGE="https://nschlia.github.io/ffmpegfs/"
SRC_URI="https://github.com/nschlia/ffmpegfs/releases/download/v${PV}/${P}.tar.gz"

LICENSE="GPL-3+"
SLOT="0"
KEYWORDS="~amd64"
IUSE="bluray dvd"

RESTRICT="test"  # needs /dev/fuse

BDEPEND="
	app-editors/vim-core
	app-text/asciidoc
	virtual/pkgconfig
	www-client/w3m
"
DEPEND="
	dev-db/sqlite:3
	dev-libs/libchardet
	media-libs/libcue:=
	media-video/ffmpeg:=
	sys-fs/fuse:0
	bluray? ( media-libs/libbluray:= )
	dvd? ( media-libs/libdvdread:= )
"
RDEPEND="${DEPEND}"

PATCHES=(
	"${FILESDIR}/ffmpegfs-2.16-cflags.patch"
	"${FILESDIR}/ffmpegfs-2.16-varcache.patch"
)

src_prepare() {
	default
	# bug 936615
	sed 's/-D_FORTIFY_SOURCE=2//' -i Makefile.am || die
	eautoreconf
}

src_configure() {
	econf \
		$(use_with bluray libbluray) \
		$(use_with dvd libdvd)
}
