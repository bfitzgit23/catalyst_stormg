# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_{11..13} )
DISTUTILS_USE_PEP517=setuptools

inherit cmake distutils-r1 git-r3 xdg-utils desktop

IUSE="+av1 +codec2 -daemon doc -extras"

DESCRIPTION="Open source softphone for voice and video over IP calling and instant messaging."
HOMEPAGE="https://www.linphone.org/en/homepage-linphone"
KEYWORDS="~amd64"
LICENSE="GPL-3"
SLOT="0"

RESTRICT="test" # Not yet evaluated - TODO

EGIT_REPO_URI="https://github.com/BelledonneCommunications/linphone-desktop.git"
EGIT_BRANCH="release/6.0"
EGIT_TAG="${PV}-CallEdition"
EGIT_SUBMODULES=(
    '*'
    '-external/linphone-sdk/external/*'
    'external/linphone-sdk/external/bv16-floatingpoint'
    'external/linphone-sdk/external/liboqs'
    'external/linphone-sdk/external/decaf'
)

RDEPEND="
    >=dev-db/soci-4.1.0
    dev-db/sqlite
    dev-libs/jsoncpp
    dev-libs/libayatana-appindicator
    dev-libs/libxml2
    dev-libs/openssl:0/3
    dev-libs/qtkeychain[qt6]
    dev-libs/xerces-c
    dev-python/pystache[${PYTHON_USEDEP}]
    dev-python/six[${PYTHON_USEDEP}]
    dev-qt/qttools:6[linguist,qml]
    dev-qt/qtdeclarative:6
    dev-qt/qtmultimedia:6
    dev-qt/qtnetworkauth:6
    media-libs/glew:0
    media-libs/libjpeg-turbo
    media-libs/libvpx
    media-libs/libyuv
    media-libs/opencore-amr
    media-libs/openh264
    media-libs/opus
    media-libs/speex
    media-libs/speexdsp
    media-libs/vo-amrwbenc
    media-libs/zxing-cpp
    media-sound/gsm
    media-video/ffmpeg
    net-libs/libsrtp:2
    net-nds/openldap
    av1? (
        media-libs/dav1d
        media-libs/libaom
    )
    codec2? ( media-libs/codec2 )
    doc? ( app-text/doxygen )
"
DEPEND="${RDEPEND}"
PATCHES=(
    "${FILESDIR}/${P}_soci.patch" # fixes compile against soci >= 4.1
)

src_unpack() {
    git-r3_src_unpack
    default
}

src_prepare() {
    # invalid files (those are directories and must be removed)
    rm -rf external/linphone-sdk/external/liboqs/scripts/copy_from_upstream/src/CMakeLists.txt || die
    rm -rf external/linphone-sdk/external/liboqs/scripts/copy_from_upstream/CMakeLists.txt || die

    # external/linphone-sdk/bctoolbox/cmake/BCToolboxCMakeUtils.cmake

    # patching non-default TLS_PEER_CN flag (this might cause serious problems)
    sed -i 's/LDAP_OPT_X_TLS_PEER_CN/0x601c/g' \
        external/linphone-sdk/liblinphone/src/ldap/ldap-contact-provider.cpp || die

    # patching post-build copyings
    sed -i -e "s~>\ \"~>\ \"/${T}/${P}~g" -e "s~/\"\ \"~\"\ \"/${T}/${P}~g" \
        Linphone/CMakeLists.txt || die

    # removing jsoncpp (it does no longer provide cmake files)
    sed -i '/find_package(JsonCPP REQUIRED)/d' external/linphone-sdk/liblinphone/CMakeLists.txt || die

    cmake_src_prepare
}

src_configure() {
    local LIBDIR="/usr/`get_libdir`"
    local mycmakeargs=(
        -DCMAKE_BUILD_TYPE=Release
        -DBUILD_SHARED_LIBS=ON
        -DENABLE_SHARED=ON

        -DENABLE_DOC=$(usex doc)
        -DENABLE_DAEMON=$(usex daemon)
        -DENABLE_TOOLS=$(usex extras)
        -DENABLE_AV1=$(usex av1)
        -DENABLE_CODEC2=$(usex codec2)

        # moving to ssl instead of mbedtls .. 
        -DENABLE_MBEDTLS=NO
        -DENABLE_OPENSSL=YES
        -DBUILD_OPENSSL=OFF
        -DENABLE_LDAP=NO
        -DBUILD_LDAP=OFF

        # not availbale libs (must be build)
        -DBUILD_BV16=ON
        -DBUILD_LIBOQS=ON

        # disabled building external libs
        -DBUILD_AOM=OFF
        -DBUILD_CODEC2=OFF
        -DBUILD_DAV1D=OFF
        -DBUILD_FFMPEG=OFF
        -DBUILD_GSM=OFF
        -DBUILD_JSONCPP=OFF
        -DBUILD_LIBJPEGTURBO=OFF
        -DBUILD_LIBSRTP2=OFF
        -DBUILD_LIBVPX=OFF
        -DBUILD_LIBXML2=OFF
        -DBUILD_LIBYUV=OFF
        -DBUILD_MBEDTLS=OFF
        -DBUILD_OPENCORE_AMR=OFF
        -DBUILD_OPENH264=OFF
        -DBUILD_OPENLDAP=OFF
        -DBUILD_OPUS=OFF
        -DBUILD_SOCI=OFF
        -DBUILD_SPEEX=OFF
        -DBUILD_SQLITE3=OFF
        -DBUILD_VO_AMRWBENC=OFF
        -DBUILD_XERCESC=OFF
        -DBUILD_ZLIB=OFF
        -DBUILD_ZXINGCPP=OFF

        # correcting targets
        -DOpenH264_TARGET=openh264
        -DJsonCPP_TARGET=jsoncpp
        -DDav1d_TARGET=dav1d
        -DAom_TARGET=aom

        # Qt6 adjustments (use system keychain)
        -DENABLE_QT_KEYCHAIN=OFF
        -DQTKEYCHAIN_TARGET_NAME=Qt6Keychain

        -DQT_I18N_TRANSLATED_LANGUAGES="de en fr"
        -DI18N_SOURCE_LANGUAGE="fr"

        # correcting plugin paths
        -DLIBLINPHONE_PLUGINS_DIR=/opt/${PN}/plugins
        -DLINPHONE_PACKAGE_PLUGINS_DIR=/opt/${PN}/plugins

        # skipping RPATH
        -DCMAKE_SKIP_RPATH=ON

        # add missing include dirs
        -DCMAKE_CXX_FLAGS=-I\ /usr/include/openh264\ -I\ /usr/include/jsoncpp\ -I\ /usr/include/mbedtls3\ -I\ "${T}/${P}"/usr/include
    )
    cmake_src_configure
}

src_compile() {
    sed -i 's/RelWithDebInfo/Release/g' \
        "${WORKDIR}/${P}_build/cmake_install.cmake" || die

    # removing root.ca from installation (fails)
    sed -i '/rootca.pem/d' \
        "${WORKDIR}/${P}_build/cmake_install.cmake" || die

    cmake_src_compile
}

src_install() {
    cmake_src_install # this might produce "errors" (corrections below)

    # package base-name (linphone)
    local PBN=${PN%%-*}

    einfo "cleaning up build-fragments.."
    rm -rf "${D}"/usr/cmake
    rm -rf "${D}"/usr/include
    rm -rf "${D}"/usr/share/*/cmake
    rm -rf "${D}"/usr/share/BCUnit
    rm -rf "${D}"/usr/share/images
    rm -rf "${D}"/usr/share/rootca.pem
    rm -rf "${D}/usr/`get_libdir`"/cmake
    rm -rf "${D}/usr/`get_libdir`"/pkgconfig

    einfo "removing external docs.."
    rm -rf "${D}"/usr/share/doc/ortp*

    einfo "installing plugin(s).."
    dodir "/opt/${PN}/plugins/"
    dosym "/usr/`get_libdir`/libsoci_core.so" "/opt/${PN}/plugins/libsoci_core.so"
    dosym "/usr/`get_libdir`/libsoci_sqlite3.so" "/opt/${PN}/plugins/libsoci_sqlite3.so"

    einfo "move binaries into right place.."
    exeinto /opt/${PN}/bin
    for exf in "${D}"/usr/bin/*; do
        doexe ${exf}                                    # install from bin (exe)
        rm ${exf}                                       # remove installed bin
    done

    # re-link main binary
    dosym /opt/${PN}/bin/${PBN}6 /usr/bin/${PBN}

    # create desktop icon
    newicon "${S}/Linphone/data/image/${PBN}.svg" ${PBN}.svg
    make_desktop_entry /usr/bin/${PBN} Linphone /usr/share/pixmaps/${PBN}.svg
}

pkg_postinst() {
    xdg_icon_cache_update
}

pkg_postrm() {
    xdg_icon_cache_update
}