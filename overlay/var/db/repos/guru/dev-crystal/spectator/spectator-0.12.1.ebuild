# Copyright 2022-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit shards

DESCRIPTION="Feature-rich testing framework for Crystal inspired by RSpec"
HOMEPAGE="https://github.com/icy-arctic-fox/spectator"
SRC_URI="https://github.com/icy-arctic-fox/${PN}/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64"

DOCS=( {ARCHITECTURE,CHANGELOG,CONTRIBUTING,README}.md )

src_prepare() {
	default

	# remove a test that might fail to build (bug 945172)
	rm spec/issues/github_issue_48_spec.cr || die
}

src_test() {
	# adopted from .gitlab-ci.yml
	shards_src_test spec/matchers/ spec/spectator/*.cr
	shards_src_test spec/docs/
	shards_src_test spec/features/
	shards_src_test spec/issues/
	shards_src_test spec/rspec/

	# Build failure
	#shards_src_test spec/spectator/dsl/

	# Compile each test individually, because otherwise
	# up to 3G of RAM is eaten by compilation.
	local t
	for t in spec/spectator/mocks/*; do
		shards_src_test "${t}"
	done
}
