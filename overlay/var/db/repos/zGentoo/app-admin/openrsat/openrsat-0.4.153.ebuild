# Copyright 1999-2026 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit toolchain-funcs desktop xdg-utils

DESCRIPTION="OpenRSAT - cross-platform RSAT-like Active Directory administration tool"
HOMEPAGE="https://github.com/tranquilit/OpenRSAT"

MORMOT2_TAG="2.4-stable"

PLTIS_VIRTUALTREES_COMMIT="031c771e2cdd075f2dc604d007de60ee6ae6421c"
PLTIS_UICOMPONENTS_COMMIT="8f9ca46b630fde9084724dd6d03eb87da39d3b1d"
PLTIS_UTILS_COMMIT="7ea84dedfedde3a5621162ec936bb2a1e6a563b5"
PLTIS_TSMBIOS_COMMIT="4dd8b34092642188ad4dcd80657976366e0eeff3"
METADARKSTYLE_COMMIT="574f800bdc135359c49df6aaee06eb36c47f8736"

SRC_URI="
    https://github.com/tranquilit/OpenRSAT/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz
    https://github.com/synopse/mORMot2/archive/refs/tags/${MORMOT2_TAG}.tar.gz -> mORMot2-${MORMOT2_TAG}.tar.gz
    https://github.com/synopse/mORMot2/releases/download/${MORMOT2_TAG}/mormot2static.tgz -> mormot2static-${MORMOT2_TAG}.tgz
    https://github.com/tranquilit/pltis_utils/archive/${PLTIS_UTILS_COMMIT}.tar.gz -> pltis_utils-${PLTIS_UTILS_COMMIT}.tar.gz
    https://github.com/tranquilit/pltis_virtualtrees/archive/${PLTIS_VIRTUALTREES_COMMIT}.tar.gz -> pltis_virtualtrees-${PLTIS_VIRTUALTREES_COMMIT}.tar.gz
    https://github.com/tranquilit/pltis_tsmbios/archive/${PLTIS_TSMBIOS_COMMIT}.tar.gz -> pltis_tsmbios-${PLTIS_TSMBIOS_COMMIT}.tar.gz
    https://github.com/tranquilit/pltis_uicomponents/archive/${PLTIS_UICOMPONENTS_COMMIT}.tar.gz -> pltis_uicomponents-${PLTIS_UICOMPONENTS_COMMIT}.tar.gz
    https://github.com/zamtmn/metadarkstyle/archive/${METADARKSTYLE_COMMIT}.tar.gz -> metadarkstyle-${METADARKSTYLE_COMMIT}.tar.gz
"

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64 ~x86"

IUSE="gtk qt6"
REQUIRED_USE="|| ( gtk qt6 )"

BDEPEND=""
DEPEND="
    >=dev-lang/fpc-3.2[source]
    gtk? ( x11-libs/gtk+:3 >=dev-lang/lazarus-4.0[gui,gtk] )
    qt6? ( dev-qt/qtbase:6[gui,widgets] >=dev-lang/lazarus-4.0[gui,qt6] )
"
RDEPEND="${DEPEND}"
S="${WORKDIR}/OpenRSAT-${PV}"
QA_PRESTRIPPED="/usr/bin/OpenRSAT"

src_prepare() {
    default

    export LAZ_PCP="${T}/lazarus-pcp"
    export LAZARUSDIR="${T}/lazarus-tree"

    local lpk  mormot2_lpk 
    local sys_laz="/usr/share/lazarus" ws="gtk3"

    # Prepare local and exported vars
    use qt6 && ws="qt6"
    mkdir -p "${LAZ_PCP}" || die
    rm -rf "${LAZARUSDIR}" || die
    cp -a "${sys_laz}" "${LAZARUSDIR}" || die

    # clear submodules
    mkdir -p "${S}/submodules" || die
    rm -rf "${S}/submodules/"* || die

    # populate submodules
    mv "${WORKDIR}/mORMot2-${MORMOT2_TAG}" "${S}/submodules/mORMot2" || die
    mv "${WORKDIR}/pltis_utils-${PLTIS_UTILS_COMMIT}" "${S}/submodules/pltis_utils" || die
    mv "${WORKDIR}/pltis_virtualtrees-${PLTIS_VIRTUALTREES_COMMIT}" "${S}/submodules/pltis_virtualtrees" || die
    mv "${WORKDIR}/pltis_tsmbios-${PLTIS_TSMBIOS_COMMIT}" "${S}/submodules/pltis_tsmbios" || die
    mv "${WORKDIR}/pltis_uicomponents-${PLTIS_UICOMPONENTS_COMMIT}" "${S}/submodules/pltis_uicomponents" || die
    mv "${WORKDIR}/metadarkstyle-${METADARKSTYLE_COMMIT}" "${S}/submodules/metadarkstyle" || die

    tar xf "${DISTDIR}/mormot2static-${MORMOT2_TAG}.tgz" -C \
        "${S}/submodules/mORMot2/static/" || die "Failed to unpack mORMot2 statics"

    # Normalize CRLF -> LF for Pascal sources (several submodules ship CRLF) - otherwise the patches will fail
    find . -type f \( -name '*.pas' -o -name '*.pp' -o -name '*.inc' -o -name '*.lpr' \) \
        -exec sed -i 's/\r$//' {} + || die

    # remove windows related stuff (missing check)
    eapply "${FILESDIR}/openrsat-0.4.153-windres.patch"

    mormot2_lpk="$(find "submodules/mORMot2" -name 'mormot2.lpk' -print -quit)"

    # load needed packages
    lazbuild --lazarusdir="${LAZARUSDIR}" --pcp="${LAZ_PCP}" --ws="${ws}" --add-package-link "${mormot2_lpk}" || die
    while IFS= read -r -d '' lpk; do
        lazbuild --lazarusdir="${LAZARUSDIR}" --pcp="${LAZ_PCP}" --add-package-link "${lpk}" || die
    done < <(find "packages" "submodules" -name '*.lpk' -print0)
}

src_compile() {
    local build_mode ws="gtk3"
    
    use qt6 && ws="qt6"
    case "$(tc-arch)" in
        amd64) build_mode="linux-x64" ;;
        x86)   build_mode="linux-i386" ;;
        #not covered!
        # arm)   build_mode="linux-arm32" ;; 
        # arm64) build_mode="linux-arm64" ;;
        *)     die "Unsupported arch: $(tc-arch)" ;;
    esac

    # compile
    lazbuild \
        --lazarusdir="${LAZARUSDIR}" \
        --pcp="${LAZ_PCP}" \
        --ws="${ws}" \
        --build-mode="${build_mode}" \
        "${S}/sources/OpenRSAT.lpi" \
        || die

    # export, as needed for install
    export BUILD_MODE=${build_mode}
    export WS=${ws}
}

src_install() {
    local bin=$(find "${S}/bin/${BUILD_MODE}" -maxdepth 1 -type f -name 'OpenRSAT' -perm -111 -print -quit)
    dobin "${bin}" || die

    newicon -s 48 "${S}/assets/icons/OpenRSAT_48.png" openrsat.png
    newicon -s 512 "${S}/assets/icons/OpenRSAT_512.png" openrsat.png

    local env_vars="GDK_BACKEND=x11 GDK_SCALE=1 GDK_DPI_SCALE=1"
    if [ ${WS} == "qt6" ]; then
        env_vars="QT_QPA_PLATFORM=xcb QT_SCALE_FACTOR=1"
    fi

    make_desktop_entry \
        --eapi9 \
        "/usr/bin/env ${env_vars} /usr/bin/OpenRSAT" \
        -d OpenRSAT \
        -n OpenRSAT \
        -i openrsat \
        -c "Science;Education;Engineering;" \
        -C "${DESCRIPTION}"
    # correcting TryExec entry (as it mirrors <command>)
    sed -i -e 's|^TryExec=.*|TryExec=/usr/bin/OpenRSAT|' \
        "${ED}/usr/share/applications/OpenRSAT.desktop" || die

    dodoc README.md 2>/dev/null || true
}

pkg_postinst() {
    xdg_icon_cache_update
}

pkg_postrm() {
    xdg_icon_cache_update
}