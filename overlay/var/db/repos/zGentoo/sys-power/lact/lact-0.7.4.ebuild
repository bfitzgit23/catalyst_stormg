# Copyright 2024-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

CRATES="
	addr2line@0.24.2
	adler2@2.0.0
	adler32@1.2.0
	ahash@0.8.11
	aho-corasick@1.1.3
	allocator-api2@0.2.21
	amdgpu-sysfs@0.18.1
	android-tzdata@0.1.1
	android_system_properties@0.1.5
	anstream@0.6.18
	anstyle-parse@0.2.6
	anstyle-query@1.1.2
	anstyle-wincon@3.0.7
	anstyle@1.0.10
	anyhow@1.0.98
	async-broadcast@0.7.2
	async-recursion@1.1.1
	async-trait@0.1.88
	autocfg@1.4.0
	backtrace@0.3.74
	bindgen@0.68.1
	bitflags@1.3.2
	bitflags@2.9.0
	bumpalo@3.17.0
	bytes@1.10.1
	cairo-rs@0.20.7
	cairo-sys-rs@0.20.7
	cc@1.2.20
	cexpr@0.6.0
	cfg-expr@0.17.2
	cfg-if@1.0.0
	cfg_aliases@0.2.1
	chrono@0.4.40
	clang-sys@1.8.1
	clap@4.5.37
	clap_builder@4.5.37
	clap_derive@4.5.32
	clap_lex@0.7.4
	colorchoice@1.0.3
	concurrent-queue@2.5.0
	condtype@1.3.0
	configparser@3.1.0
	console@0.15.11
	core-foundation-sys@0.8.7
	core2@0.4.0
	crc32fast@1.4.2
	crossbeam-utils@0.8.21
	ctrlc@3.4.6
	darling@0.20.11
	darling_core@0.20.11
	darling_macro@0.20.11
	dary_heap@0.3.7
	deranged@0.4.0
	diff@0.1.13
	divan-macros@0.1.21
	divan@0.1.21
	dlopen2@0.7.0
	dlopen2_derive@0.4.0
	easy_fuser@0.4.0
	either@1.15.0
	encode_unicode@1.0.0
	endi@1.1.0
	enum_dispatch@0.3.13
	enumflags2@0.7.11
	enumflags2_derive@0.7.11
	equivalent@1.0.2
	errno@0.3.11
	event-listener-strategy@0.5.4
	event-listener@5.4.0
	fastrand@2.3.0
	field-offset@0.3.6
	filetime@0.2.25
	flume@0.11.1
	fnv@1.0.7
	fragile@2.0.1
	fuser@0.15.1
	futures-channel@0.3.31
	futures-core@0.3.31
	futures-executor@0.3.31
	futures-io@0.3.31
	futures-lite@2.6.0
	futures-macro@0.3.31
	futures-sink@0.3.31
	futures-task@0.3.31
	futures-util@0.3.31
	futures@0.3.31
	gdk-pixbuf-sys@0.20.7
	gdk-pixbuf@0.20.9
	gdk4-sys@0.9.6
	gdk4@0.9.6
	getrandom@0.2.16
	getrandom@0.3.2
	gimli@0.31.1
	gio-sys@0.20.9
	gio@0.20.9
	glib-macros@0.20.7
	glib-sys@0.20.9
	glib@0.20.9
	glob@0.3.2
	gobject-sys@0.20.9
	graphene-rs@0.20.9
	graphene-sys@0.20.7
	gsk4-sys@0.9.6
	gsk4@0.9.6
	gtk4-macros@0.9.5
	gtk4-sys@0.9.6
	gtk4@0.9.6
	hashbrown@0.14.5
	hashbrown@0.15.2
	heck@0.5.0
	hermit-abi@0.3.9
	hex@0.4.3
	home@0.5.11
	iana-time-zone-haiku@0.1.2
	iana-time-zone@0.1.63
	ident_case@1.0.1
	indexmap@2.9.0
	inotify-sys@0.1.5
	inotify@0.11.0
	insta@1.43.0
	is_terminal_polyfill@1.70.1
	itoa@1.0.15
	js-sys@0.3.77
	kqueue-sys@1.0.4
	kqueue@1.0.8
	lazy_static@1.5.0
	lazycell@1.3.0
	libadwaita-sys@0.7.2
	libadwaita@0.7.2
	libc@0.2.172
	libdrm_amdgpu_sys@0.8.4
	libflate@2.1.0
	libflate_lz77@2.1.0
	libloading@0.8.6
	libredox@0.1.3
	linux-raw-sys@0.4.15
	linux-raw-sys@0.9.4
	lock_api@0.4.12
	log@0.4.27
	matchers@0.1.0
	memchr@2.7.4
	memoffset@0.9.1
	minimal-lexical@0.2.1
	miniz_oxide@0.8.8
	mio@1.0.3
	nanorand@0.7.0
	nix@0.29.0
	nom@7.1.3
	notify-types@2.0.0
	notify@8.0.0
	nu-ansi-term@0.46.0
	num-conv@0.1.0
	num-traits@0.2.19
	num_cpus@1.16.0
	num_threads@0.1.7
	object@0.36.7
	once_cell@1.21.3
	opencl-sys@0.6.0
	ordered-stream@0.2.0
	os-release@0.1.0
	overload@0.1.1
	page_size@0.6.0
	pango-sys@0.20.9
	pango@0.20.9
	parking@2.2.1
	pciid-parser@0.8.0
	peeking_take_while@0.1.2
	pin-project-lite@0.2.16
	pin-utils@0.1.0
	pkg-config@0.3.32
	plotters-backend@0.3.7
	plotters-cairo@0.7.0
	plotters@0.3.7
	powerfmt@0.2.0
	pretty_assertions@1.4.1
	prettyplease@0.2.32
	proc-macro-crate@3.3.0
	proc-macro2@1.0.95
	quote@1.0.40
	r-efi@5.2.0
	redox_syscall@0.5.11
	regex-automata@0.1.10
	regex-automata@0.4.9
	regex-lite@0.1.6
	regex-syntax@0.6.29
	regex-syntax@0.8.5
	regex@1.11.1
	relm4-components@0.9.1
	relm4-css@0.9.0
	relm4-macros@0.9.1
	relm4@0.9.1
	rle-decode-fast@1.0.3
	rustc-demangle@0.1.24
	rustc-hash@1.1.0
	rustc_version@0.4.1
	rustix@0.38.44
	rustix@1.0.5
	rustversion@1.0.20
	ryu@1.0.20
	same-file@1.0.6
	scopeguard@1.2.0
	semver@1.0.26
	serde-error@0.1.3
	serde@1.0.219
	serde_derive@1.0.219
	serde_json@1.0.140
	serde_repr@0.1.20
	serde_spanned@0.6.8
	serde_with@3.12.0
	serde_with_macros@3.12.0
	serde_yaml@0.9.34+deprecated
	sharded-slab@0.1.7
	shlex@1.3.0
	signal-hook-registry@1.4.5
	similar@2.7.0
	simple_logger@5.0.0
	slab@0.4.9
	smallvec@1.15.0
	socket2@0.5.9
	spin@0.9.8
	static_assertions@1.1.0
	strsim@0.11.1
	syn@2.0.100
	system-deps@7.0.3
	tar@0.4.44
	target-lexicon@0.12.16
	tempfile@3.19.1
	termcolor@1.4.1
	terminal_size@0.4.2
	thiserror-impl@1.0.69
	thiserror-impl@2.0.12
	thiserror@1.0.69
	thiserror@2.0.12
	thread-priority@1.2.0
	thread_local@1.1.8
	threadpool@1.8.1
	time-core@0.1.4
	time-macros@0.2.22
	time@0.3.41
	tokio-macros@2.5.0
	tokio@1.44.2
	toml@0.8.21
	toml_datetime@0.6.9
	toml_edit@0.22.25
	tracing-attributes@0.1.28
	tracing-core@0.1.33
	tracing-log@0.2.0
	tracing-subscriber@0.3.19
	tracing@0.1.41
	tracker-macros@0.2.2
	tracker@0.2.2
	uds_windows@1.1.0
	unicode-ident@1.0.18
	unsafe-libyaml@0.2.11
	utf8parse@0.2.2
	valuable@0.1.1
	vergen@8.3.2
	version-compare@0.2.0
	version_check@0.9.5
	walkdir@2.5.0
	wasi@0.11.0+wasi-snapshot-preview1
	wasi@0.14.2+wasi-0.2.4
	wasm-bindgen-backend@0.2.100
	wasm-bindgen-macro-support@0.2.100
	wasm-bindgen-macro@0.2.100
	wasm-bindgen-shared@0.2.100
	wasm-bindgen@0.2.100
	web-sys@0.3.77
	which@4.4.2
	winapi-i686-pc-windows-gnu@0.4.0
	winapi-util@0.1.9
	winapi-x86_64-pc-windows-gnu@0.4.0
	winapi@0.3.9
	windows-core@0.61.0
	windows-implement@0.60.0
	windows-interface@0.59.1
	windows-link@0.1.1
	windows-result@0.3.2
	windows-strings@0.4.0
	windows-sys@0.48.0
	windows-sys@0.52.0
	windows-sys@0.59.0
	windows-targets@0.48.5
	windows-targets@0.52.6
	windows_aarch64_gnullvm@0.48.5
	windows_aarch64_gnullvm@0.52.6
	windows_aarch64_msvc@0.48.5
	windows_aarch64_msvc@0.52.6
	windows_i686_gnu@0.48.5
	windows_i686_gnu@0.52.6
	windows_i686_gnullvm@0.52.6
	windows_i686_msvc@0.48.5
	windows_i686_msvc@0.52.6
	windows_x86_64_gnu@0.48.5
	windows_x86_64_gnu@0.52.6
	windows_x86_64_gnullvm@0.48.5
	windows_x86_64_gnullvm@0.52.6
	windows_x86_64_msvc@0.48.5
	windows_x86_64_msvc@0.52.6
	winnow@0.7.7
	wit-bindgen-rt@0.39.0
	wrapcenum-derive@0.4.1
	xattr@1.5.0
	xdg-home@1.3.0
	yansi@1.0.1
	zbus@5.5.0
	zbus_macros@5.5.0
	zbus_names@4.2.0
	zerocopy-derive@0.7.35
	zerocopy-derive@0.8.25
	zerocopy@0.7.35
	zerocopy@0.8.25
	zvariant@5.4.0
	zvariant_derive@5.4.0
	zvariant_utils@3.2.0
"

declare -A GIT_CRATES=(
	[cl3]='https://github.com/kenba/cl3;cb019aac330ab8243804be02b7183a1c5a211caa;cl3-%commit%'
	[copes]='https://gitlab.com/corectrl/copes;1bc002a030345787f0e11e0317975a2e4f2a22ee;copes-%commit%'
	[nvml-wrapper-sys]='https://github.com/ilya-zlobintsev/nvml-wrapper;d245c3010c72466cfb572f5baf91c91f7294bb36;nvml-wrapper-%commit%/nvml-wrapper-sys'
	[nvml-wrapper]='https://github.com/ilya-zlobintsev/nvml-wrapper;d245c3010c72466cfb572f5baf91c91f7294bb36;nvml-wrapper-%commit%/nvml-wrapper'
)

LLVM_COMPAT=( {18..20} )
RUST_MIN_VER="1.85.1"

inherit cargo llvm-r2 xdg

DESCRIPTION="Linux GPU Control Application"
HOMEPAGE="https://github.com/ilya-zlobintsev/LACT"
SRC_URI="
	https://github.com/ilya-zlobintsev/LACT/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz
	${CARGO_CRATE_URIS}
"
S="${WORKDIR}/${P^^}" # uppercase ${P}

LICENSE="MIT"
LICENSE+="
	Apache-2.0 Apache-2.0-with-LLVM-exceptions BSD CC0-1.0 GPL-3 GPL-3+
	ISC MIT Unicode-3.0 ZLIB
"
SLOT="0"
KEYWORDS="~amd64"
IUSE="gui gnome test video_cards_nvidia"
REQUIRED_USE="gnome? ( gui ) test? ( gui )"
RESTRICT="!test? ( test )"

COMMON_DEPEND="
	virtual/opencl
	x11-libs/libdrm[video_cards_amdgpu]
	gui? (
		dev-libs/glib:2
		gui-libs/gtk:4[introspection]
		media-libs/fontconfig
		media-libs/freetype
		media-libs/graphene
		x11-libs/cairo
		x11-libs/pango
	)
	gnome? ( >=gui-libs/libadwaita-1.4.0:1 )
"
RDEPEND="
	${COMMON_DEPEND}
	dev-util/vulkan-tools
	sys-apps/hwdata
"
DEPEND="
	${COMMON_DEPEND}
	test? ( sys-fs/fuse:3 )
"
# libclang is required for bindgen
BDEPEND="
	virtual/pkgconfig
	$(llvm_gen_dep 'llvm-core/clang:${LLVM_SLOT}')
"

QA_FLAGS_IGNORED="usr/bin/lact"

pkg_setup() {
	llvm-r2_pkg_setup
	rust_pkg_setup
}

src_configure() {
	sed -i "/^strip =/d" Cargo.toml || die
	sed -i "s|target/release|$(cargo_target_dir)|" Makefile || die

	local myfeatures=(
		$(usev gui lact-gui)
		$(usev gnome adw)
		$(usev video_cards_nvidia nvidia)
	)
	cargo_src_configure --no-default-features -p lact
}

src_install() {
	emake DESTDIR="${D}" PREFIX="${EPREFIX}/usr" install
	newinitd res/lact-daemon-openrc lactd
}

src_test() {
	local skip=(
		# requires newer sys-apps/hwdata
		--skip tests::snapshot_everything
	)
	cargo_src_test --workspace -- "${skip[@]}"
}
