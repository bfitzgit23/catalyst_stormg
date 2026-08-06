# Copyright 1999-2023 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2
 
EAPI=8
 
inherit multilib-minimal

DESCRIPTION="Portable, lightweight framework for the Objective-C language"
HOMEPAGE="https://objfw.nil.im"
SRC_URI="https://objfw.nil.im/downloads/${P}.tar.gz"
 
LICENSE="GPL-2 GPL-3 QPL"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE="+llvm doc"

DEPEND=""
RDEPEND="${DEPEND}"
BDEPEND="
doc? ( app-doc/doxygen )
|| (
    llvm? ( <llvm-core/llvm-17.0.0[${MULTILIB_USEDEP}] )
    sys-devel/gcc[objc]
)"

src_prepare() {
    default
    multilib_copy_sources
}

multilib_src_configure() {
    local myconf=(OBJC=gcc)
    use llvm && myconf=(OBJC=clang)
    if [ $MULTILIB_ABI_FLAG == abi_x86_32 ]; then
        ECONF_SOURCE="${S}" econf "${myconf[@]} -m32"
    else
        ECONF_SOURCE="${S}" econf "${myconf[@]}"
    fi
}

multilib_src_install() {
    emake install DESTDIR="${D}"
    if use doc && multilib_is_native_abi; then
        emake docs
        dodoc -r docs/.
    fi    
    einstalldocs
}
