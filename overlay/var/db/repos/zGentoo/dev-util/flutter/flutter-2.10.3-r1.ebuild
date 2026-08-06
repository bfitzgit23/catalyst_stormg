# Copyright 1999-2022 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2
EAPI=8

DESCRIPTION="Google's SDK for crafting beautiful, fast user experiences for mobile, web, and desktop from a single codebase"
HOMEPAGE="https://flutter.dev"

SRC_URI="https://storage.googleapis.com/${PN}_infra_release/releases/stable/linux/${PN}_linux_${PV}-stable.tar.xz"
KEYWORDS="amd64"

SLOT="0"
LICENSE="BSD-3"
IUSE="X wayland +android"

RDEPEND="
    app-shells/bash
    net-misc/curl
    dev-vcs/git
    sys-apps/coreutils
    app-arch/unzip
    app-arch/xz-utils
    app-arch/zip
    X? ( virtual/glu )
    wayland? ( virtual/glu )
    android? ( dev-util/android-sdk-cmdline-tools )
"
DEPEND="${RDEPEND}"
BDEPEND="acct-group/${PN}"

QA_PRESTRIPPED="
    opt/${PN}/bin/cache/dart-sdk/bin/dartaotruntime
    opt/${PN}/bin/cache/dart-sdk/bin/utils/gen_snapshot
    opt/${PN}/bin/cache/dart-sdk/bin/dart
    opt/${PN}/bin/cache/artifacts/engine/linux-x64-release/gen_snapshot
    opt/${PN}/bin/cache/artifacts/engine/linux-x64-release/libflutter_linux_gtk.so
    opt/${PN}/bin/cache/artifacts/engine/android-arm-release/linux-x64/gen_snapshot
    opt/${PN}/bin/cache/artifacts/engine/android-x64-profile/linux-x64/gen_snapshot
    opt/${PN}/bin/cache/artifacts/engine/linux-x64-profile/gen_snapshot
    opt/${PN}/bin/cache/artifacts/engine/linux-x64-profile/libflutter_linux_gtk.so
    opt/${PN}/bin/cache/artifacts/engine/android-arm-profile/linux-x64/gen_snapshot
    opt/${PN}/bin/cache/artifacts/engine/linux-x64/libflutter_linux_gtk.so
    opt/${PN}/bin/cache/artifacts/engine/linux-x64/font-subset
    opt/${PN}/bin/cache/artifacts/engine/linux-x64/flutter_tester
    opt/${PN}/bin/cache/artifacts/engine/android-arm64-release/linux-x64/gen_snapshot
    opt/${PN}/bin/cache/artifacts/engine/android-x64-release/linux-x64/gen_snapshot
    opt/${PN}/bin/cache/artifacts/engine/android-arm64-profile/linux-x64/gen_snapshot
"

S="${WORKDIR}/${PN}"

src_install() {
    insinto /opt/${PN}
    # dirs (yep, .git is needed as flutter depends on it)
    doins -r .git
    doins -r bin
    doins -r packages
    
    # bins
    chmod +x ${D}/opt/${PN}/bin/{dart,flutter}
    chmod +x ${D}/opt/${PN}/bin/cache/dart-sdk/bin/dart*
    chmod +x ${D}/opt/${PN}/bin/cache/dart-sdk/bin/utils/gen_snapshot
    chmod +x ${D}/opt/${PN}/bin/cache/artifacts/engine/**/linux-x64/gen_snapshot
    chmod +x ${D}/opt/${PN}/bin/cache/artifacts/engine/linux-x64*/gen_snapshot
    chmod +x ${D}/opt/${PN}/bin/cache/artifacts/engine/linux-x64/flutter_tester
    chmod +x ${D}/opt/${PN}/bin/cache/artifacts/engine/linux-x64/font-subset
    chmod +x ${D}/opt/${PN}/bin/internal/*.sh

    # general permissions
    chown -R root:${PN} ${D}/opt/${PN}
    chmod g+w -R ${D}/opt/${PN}
    chmod +s ${D}/opt/${PN}

    use android && 

    # docs
    dodoc AUTHORS CODE_OF_CONDUCT.md CODEOWNERS CONTRIBUTING.md LICENSE \
        PATENT_GRANT README.md TESTOWNERS

    # environment
    doenvd ${FILESDIR}/99${PN}
}

pkg_postinst() {
    elog "\nDisabeling telemetry must be done before cache init:"
    elog ">> flutter config --no-analytics\n"
    elog "To initialize flutter, use:\n>> flutter precache\n"
    elog "To use flutter, add the desired user to the flutter group:"
    elog ">> usermod -aG flutter <username>\n"
    ewarn "\nWARNING:"
    ewarn "After flutter is installed you need to relaod the whole"
    ewarn "(user-)session, or simply reboot to persist the group settings.\n"
}
