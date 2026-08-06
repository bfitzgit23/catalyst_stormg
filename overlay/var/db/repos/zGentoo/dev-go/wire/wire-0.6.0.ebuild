# Copyright 1999-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="Wire: Automated Initialization in Go"
HOMEPAGE="https://github.com/google/${PN}"

# creating vendor bundle:
# >> git clone https://github.com/google/wire -b v<version> /tmp/wire
# >> cd /tmp/wire && version=`git describe --tags | sed -E "s/v([0-9.]+)/\1/g"`
# >> go mod vendor && mkdir wire-${version} && mv vendor wire-${version}/vendor
# >> tar -caf wire-${version}-vendor.tar.xz wire-${version}/vendor

SRC_URI="
	https://github.com/google/${PN}/archive/v${PV/_rc/-rc.}.tar.gz -> ${P}.tar.gz
	https://vendors.simple-co.de/${PN}/${P}-vendor.tar.xz
"

KEYWORDS="~amd64"
LICENSE="Apache-2.0"
SLOT="0"

DEPEND="dev-lang/go"

src_prepare() {
	default
	## seems like a typo - fixin it
	sed -i 's/go 1.12/go 1.22/g' go.mod
	echo "require golang.org/x/mod v0.14.0 // indirect" >> go.mod
}

src_compile() {
	GO111MODULE=on GOCACHE="${T}"/go-cache go build -mod=vendor -o ./bin/${PN} ./cmd/wire/main.go
}

src_install() {
	dobin bin/*
	dodoc {README,CONTRIBUTING}.md
}
