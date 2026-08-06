# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit desktop xdg-utils

MY_PN=${PN/-bin}
PB_DATE="20250731"

DESCRIPTION="A software reverse engineering (SRE) suite of tools developed by NSA's Research Directorate"
HOMEPAGE="https://ghidra-sre.org/ https://github.com/NationalSecurityAgency/ghidra/"
SRC_URI="https://github.com/NationalSecurityAgency/${MY_PN}/releases/download/Ghidra_${PV}_build/${MY_PN}_${PV}_PUBLIC_${PB_DATE}.zip -> ${P}.zip"

LICENSE="Apache-2.0 && public-domain"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE=""

DEPEND=">=virtual/jdk-11.0.0"
RDEPEND="${DEPEND}"
BDEPEND=""

# custom build dir (from zip)
S=${WORKDIR}/${MY_PN}_${PV}_PUBLIC
QA_PREBUILT="/usr/bin/ghidra"
QA_PRESTRIPPED="
    /usr/share/ghidra/docs/GhidraClass/ExerciseFiles/Advanced/sharedReturn
"

src_install() {
    dodir /usr/share/ghidra
    mv ${S}/* ${ED}/usr/share/ghidra || die "mv failed"

    dodir /usr/bin
    dosym /usr/share/ghidra/ghidraRun /usr/bin/ghidra

    insinto /usr/share/ghidra
    doins ${FILESDIR}/ghidra_icon.png

    make_desktop_entry /usr/bin/ghidra "Ghidra" /usr/share/ghidra/ghidra_icon.png "Development"
}

pkg_postinst() {
    xdg_icon_cache_update
    xdg_desktop_database_update
    xdg_mimeinfo_database_update
}

pkg_postrm() {
    xdg_icon_cache_update
    xdg_desktop_database_update
    xdg_mimeinfo_database_update
}
