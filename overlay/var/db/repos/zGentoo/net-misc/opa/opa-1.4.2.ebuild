# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit go-module

DESCRIPTION="Open Policy Agent (OPA) is an open source, general-purpose policy engine that enables unified, context-aware policy enforcement across the entire stack."
HOMEPAGE="https://www.openpolicyagent.org https://github.com/open-policy-agent/opa"
SRC_URI="https://github.com/open-policy-agent/${PN}/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="Apache-2.0"
SLOT="0"
KEYWORDS="~amd64 ~x86"
RESTRICT="test"

src_compile() {
    ego build
}

src_install() {
    dobin ${PN}
    default
}
