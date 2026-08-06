# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit go-module systemd
go-module_set_globals

# commit must be set manually to match the tagged version
COMMIT="6ac516b2236607f3afdfbd1cff7d0cb86f1cf1a9"
PN_WEB="${PN}-webconsole"
WEB_VER="1.0.18" # see Makefile for bundled version

DESCRIPTION="Open-Source immutable database"
HOMEPAGE="https://immudb.io/"
SRC_URI="
    https://github.com/codenotary/${PN}/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz
    https://vendors.simple-co.de/${PN}/${P}-deps.tar.xz
    webconsole? (
        https://github.com/codenotary/${PN_WEB}/releases/download/v${WEB_VER}/${PN_WEB}.tar.gz -> ${PN}-${WEB_VER}-webconsole.tar.gz
    )
"
RESTRICT="mirror"

LICENSE="BUSL-1.1"
SLOT="0"
KEYWORDS="~amd64"
IUSE="webconsole"

DEPEND="
    acct-user/${PN}
    acct-group/${PN}
"
RDEPEND="${DEPEND}"
BDEPEND=""

src_prepare() {
    default
    use webconsole && mv ${WORKDIR}/dist ${S}/webconsole
}

src_configure() {
    GOFLAGS+=""

    # change all IP-Wildcards to localhost
    sed -i 's/0.0.0.0/127.0.0.1/g' configs/*.toml || die

    # disable pgsql by default (supports pgsql compatible clients)
    sed -i 's/pgsql-server = true/pgsql-server = false/g' configs/${PN}.toml || die

    # disable metrics by default
    echo "metrics-server = false" >> configs/${PN}.toml

    # disable web-server if not used
    use webconsole || echo "web-server = false" >> configs/${PN}.toml
}

src_compile() {
    local ldflags="\
        -X \"github.com/codenotary/immudb/cmd/version.Version=${PV}\"\
        -X \"github.com/codenotary/immudb/cmd/version.Commit=${COMMIT}\"\
        -X \"github.com/codenotary/immudb/cmd/version.BuiltBy=portage\"\
        -X \"github.com/codenotary/immudb/cmd/version.BuiltAt=$(date +%s)\"\
    "

    # webconsole
    if use webconsole; then
        go generate -tags "webconsole" ${S}/webconsole
        go build -tags "webconsole" -ldflags="${ldflags}" -o ${S}/bin/immudb ${S}/cmd/immudb
    fi

    # binaries
    use webconsole || go build -ldflags="${ldflags}" -o ${S}/bin/immudb ${S}/cmd/immudb
    go build -ldflags="${ldflags}" -o ${S}/bin/immuadmin ${S}/cmd/immuadmin
    go build -ldflags="${ldflags}" -o ${S}/bin/immuclient ${S}/cmd/immuclient
    go build -ldflags="${ldflags}" -o ${S}/bin/immutest ${S}/cmd/immutest

    # manpages
    go run ${S}/cmd/immuclient mangen ${S}/cmd/docs/man/immuclient
    go run ${S}/cmd/immuadmin mangen ${S}/cmd/docs/man/immuadmin
    go run ${S}/cmd/immudb mangen ${S}/cmd/docs/man/immudb
    go run ${S}/cmd/immutest mangen ${S}/cmd/docs/man/immutest
}

src_install() {
    dobin bin/*
    
    insinto /usr/share/${PN}/configs
    for f in configs/*.toml; do
        local fb=$(basename ${f})
        doins configs/${fb}
        dosym /usr/share/${PN}/configs/${fb} /etc/${PN}/${fb}
    done

    if use webconsole; then
        insinto /usr/share/${PN}/webconsole
        doins -r webconsole/dist
    fi

    keepdir /usr/share/${PN}/data
    fowners ${PN}:${PN} /usr/share/${PN}/data

    systemd_dounit ${FILESDIR}/${PN}.service

    doman cmd/docs/man/**/*
    dodoc README.md
}