# Copyright 1999-2025 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
EAPI=8

inherit desktop pax-utils xdg

DESCRIPTION="A complete, free Microsoft Office-compatible alternative office suite"
HOMEPAGE="https://www.freeoffice.com"
SRC_URI="https://www.softmaker.net/down/softmaker-${PN}-2024-${PV}-amd64.tgz"

LICENSE="SoftMaker"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE="pax_kernel"

LANGUAGES="ar bg da de el en-GB en-US es et fi fr hu id it ja kk ko lt lv nl pl pt pt-BR ro ru sl sv tr uk zh"

for lang in ${LANGUAGES}; do
	IUSE+=" l10n_${lang%:*}"
done

RESTRICT="mirror strip"

DEPEND="
	app-admin/chrpath
	app-arch/xz-utils"
RDEPEND="
	${DEPEND}
	media-libs/mesa
	net-misc/curl
	x11-libs/libXrandr"

QA_PRESTRIPPED="*"

src_unpack(){
	default
	xz -d "${PN}2024.tar.lzma" || die
	mkdir -p "${WORKDIR}/${P}"
	tar x -f "${PN}2024.tar" \
		-C "${WORKDIR}/${P}" \
		&& rm "${PN}2024.tar" || die
	rm "install${PN}"
}

src_prepare(){
	chrpath --delete "textmaker"
	chrpath --delete "planmaker"
	chrpath --delete "presentations"

	# A switch case for some bad language codes
	for lang in ${LANGUAGES}; do
		use l10n_${lang%:*} && continue
		declare suffix
		case ${lang%:*} in
			da)
				suffix="dk"
			;;
			el)
				suffix="gr"
			;;
			en-US)
				suffix="us"
			;;
			en-GB)
				suffix="uk"
			;;
			et)
				suffix="ee"
			;;
			ja)
				suffix="jp"
			;;
			kk)
				suffix="kz"
			;;
			ko)
				suffix="kr"
			;;
			pt-BR)
				suffix="pb"
			;;
			sl)
				suffix="si"
			;;
			sv)
				suffix="se"
			;;
			uk)
				suffix="ua"
			;;
			*)
				suffix="${lang%:*}"
			;;
		esac
		rm -rf html_${suffix}
		rm *_${suffix}.dwr
	done

	default
}

src_install(){
	mkdir -p "${ED%/}/usr/$(get_libdir)/${PN}"
	cp -r . "${ED%/}/usr/$(get_libdir)/${PN}/"
	for m in "${FILESDIR}"/*.desktop; do
		domenu "${m}"
	done
	for e in planmaker presentations textmaker; do
		dobin "${FILESDIR}/${PN}-${e}"
	done
	for size in 16 32 48; do
		newicon -s ${size} icons/pml_${size}.png ${PN}-planmaker.png
		newicon -s ${size} icons/prl_${size}.png ${PN}-presentations.png
		newicon -s ${size} icons/tml_${size}.png ${PN}-textmaker.png
	done
	insinto /usr/share/mime/packages
	doins mime/softmaker-${PN}24.xml
	if use pax_kernel; then
		pax-mark -m "${ED%/}"/usr/$(get_libdir)/${PN}/planmaker
		pax-mark -m "${ED%/}"/usr/$(get_libdir)/${PN}/presentations
		pax-mark -m "${ED%/}"/usr/$(get_libdir)/${PN}/textmaker
	fi
}

pkg_postinst(){
	einfo
	elog "In order to use Softmaker Freeoffice, you need a serial number."
	elog "To obtain a valid free serial number, please visit"
	elog "https://www.${PN}.com/en/download"
	einfo
	xdg_pkg_postinst
}