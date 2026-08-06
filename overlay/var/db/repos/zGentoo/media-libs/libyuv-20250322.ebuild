# Copyright 1999-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake git-r3

DESCRIPTION="Open source project that includes YUV scaling and conversion functionality."
HOMEPAGE="https://chromium.googlesource.com/libyuv/libyuv"
KEYWORDS="~amd64 ~x86"
LICENSE="MIT CC-BY-4.0 BSD ISC"
SLOT="0"
RESTRICT="test" # not yet tested

EGIT_REPO_URI="https://github.com/lemenkov/libyuv.git"
EGIT_COMMIT="0fd4581"

BDEPEND=">=media-libs/libjpeg-turbo-3.0.0"

src_unpack() {
    git-r3_src_unpack
    default
}

src_prepare() {
    default
    cmake_src_prepare
}

src_configure() {
    cmake_src_configure
}

src_compile() {
    cmake_src_compile
}

src_install() {
    cmake_src_install

    # correct library installation (/usr/lib isn't allowed!)
    mv "${D}"/usr/lib "${T}"/
    dolib.a "${T}"/lib/${PN}.a
    dolib.so "${T}"/lib/${PN}.so
}