# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cdrom estack

DESCRIPTION="Data files for Descent 2: The Vertigo Series"
HOMEPAGE="https://www.interplay.com"
S="${WORKDIR}"
LICENSE="descent-data"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE="videos"
RESTRICT="bindist"

src_unpack() {
	cdrom_get_cds vertigo/d2x.hog:hoard.ham

	case ${CDROM_SET} in
		0) einfo "Found Descent 2 Vertigo Series CD" ;;
		1) einfo "Found Descent 2 Vertigo Series installation" ;;
	esac

	cd "${CDROM_ABSMATCH%/*}" || die
	eshopts_push -s globstar nocaseglob nullglob

	# Strip directories
	# Lowercase
	# *.{hog,mn2} into data/missions
	# Remainder into data

	tar -c -f - \
		--mode=u+w \
		--ignore-case \
		--xform='s:.*/::xg' \
		--xform='s:.*:\L\0:x' \
		--xform='s:.*\.(hog|mn2)$:data/missions/\0:x' \
		--xform='s:^[^/]+$:data/\0:x' \
		--exclude="$(use videos || echo '*.mvl')" \
		**/{hoard.ham,d2x-h.mvl,{d2x,panic}.{hog,mn2}}* \
		| tar -x -f - -C "${WORKDIR}"

	assert "tar failed"
	eshopts_pop
}

src_install() {
	insinto /usr/share/games/d2x
	doins -r data/*
}

pkg_postinst() {
	elog "A client is needed to run the game, e.g. games-action/dxx-rebirth."
	echo
}
