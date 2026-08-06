# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit desktop java-pkg-2

DESCRIPTION="yEd Graph Editor - High-quality diagrams made easy"
HOMEPAGE="https://www.yworks.com/en/products_yed_about.html"
SRC_URI="https://www.yworks.com/resources/yed/demo/yEd-${PV}.zip"
MY_JAR="${P}.jar"
LICENSE="yEd"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE=""

RDEPEND=">=virtual/jre-1.8"
DEPEND="
	app-arch/unzip
	${RDEPEND}"

src_unpack() {
	unzip "${DISTDIR}/${A}" -d "${S}"
}

src_install() {
	java-pkg_dojar "${S}/${P}"/lib/*
	java-pkg_dojar "${S}/${P}"/${PN}.jar
	java-pkg_dolauncher yed --jar ${PN}.jar
	doicon "${S}/${P}/icons/${PN}32.png"
	make_desktop_entry ${PN} "yEd Graph Editor" ${PN}32 "Graphics;2DGraphics"
	dodoc "${S}/${P}"/license.html
}
