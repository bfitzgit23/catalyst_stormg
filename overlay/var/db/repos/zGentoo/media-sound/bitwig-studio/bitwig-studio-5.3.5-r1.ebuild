# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit desktop unpacker xdg

DESCRIPTION="Multi-platform music-creation system for production, performance and DJing"
HOMEPAGE="https://bitwig.com"
SRC_URI="https://www.bitwig.com/dl/Bitwig%20Studio/${PV}/installer_linux/ -> ${P}.deb"
LICENSE="Bitwig"
SLOT="0"
KEYWORDS="~amd64"
RESTRICT="fetch"

MY_SLUG="opt/${PN}"

DEPEND=""
RDEPEND="${DEPEND}
    app-arch/bzip2
    dev-libs/expat
    gnome-extra/zenity
    media-video/ffmpeg
    media-libs/alsa-lib
    media-libs/fontconfig
    media-libs/freetype
    media-libs/libpng:0/16
    media-libs/mesa
    sys-libs/zlib
    virtual/opengl
    virtual/udev
"

QA_PRESTRIPPED="
    ${MY_SLUG}/bitwig-studio
    ${MY_SLUG}/bin/**/*
    ${MY_SLUG}/lib/**/*
"

S=${WORKDIR}

pkg_nofetch() {
    einfo "Please download ${P}.deb from the manufacturers side, using:"
    einfo "https://www.bitwig.com/dl/Bitwig%20Studio/${PV}/installer_linux/"
    einfo "and place the file into your DISTDIR"
}

src_install() {
    # preparations (create destination and set as target)
    TARGET=/${MY_SLUG}
    dodir ${TARGET}
    insinto ${TARGET}

    # remove ffmpeg
    rm -f ${MY_SLUG}/bin/ff*

    # install docs
    dodoc -r ${MY_SLUG}/resources/doc

    # install files (copy)
    chmod +x ${MY_SLUG}/lib/jre/lib
    chmod +x ${MY_SLUG}/lib/jre/lib/server
    chmod +x ${MY_SLUG}/lib/jre/lib/securit
    doins -r ${MY_SLUG}/*

    fperms +x ${TARGET}/bitwig-studio
    
    chmod +x "${ED}"${TARGET}/bin/*
    fperms 755 ${TARGET}/lib/jre/lib/*.so \
        ${TARGET}/lib/jre/lib/classlist \
        ${TARGET}/lib/jre/lib/jexec \
        ${TARGET}/lib/jre/lib/jspawnhelper \
        ${TARGET}/lib/jre/bin/keytool \
        ${TARGET}/lib/jre/bin/jrunscript
    
    dosym ${TARGET}/bitwig-studio /usr/bin/bitwig-studio

    # desktop file and icons
    doicon -s scalable usr/share/icons/hicolor/scalable/apps/com.bitwig.BitwigStudio.svg
    sed -i \
        -e 's/Categories=.*/Categories=AudioVideo;Audio;AudioVideoEditing/' \
        -e '/Version=1.5/d' \
        usr/share/applications/com.bitwig.BitwigStudio.desktop || die 'sed on desktop file failed'
    domenu usr/share/applications/com.bitwig.BitwigStudio.desktop
    doicon -s scalable -c mimetypes usr/share/icons/hicolor/scalable/mimetypes/*.svg
    insinto /usr/share/mime/packages
    doins usr/share/mime/packages/com.bitwig.BitwigStudio.xml
}
