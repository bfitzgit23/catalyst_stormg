# Copyright 2024-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

ROCM_VERSION=7.1
inherit cmake go-module rocm systemd

DESCRIPTION="Get up and running with large language models."
HOMEPAGE="https://ollama.com"
SRC_URI="
    https://github.com/ollama/${PN}/archive/refs/tags/v${PV}.tar.gz -> ${P}.gh.tar.gz
    https://vendors.simple-co.de/${PN}/${PN}-${PV}-deps.tar.xz
"
S="${WORKDIR}/${PN}-${PV}"
LICENSE="MIT"
SLOT="0"

KEYWORDS="~amd64"

IUSE="cuda systemd video_cards_amdgpu cpu_flags_x86_avx cpu_flags_x86_avx2
cpu_flags_x86_avx512f cpu_flags_x86_avx512vbmi cpu_flags_x86_avx512_vnni
cpu_flags_x86_avx512_bf16
"

REQUIRED_USE="
    cpu_flags_x86_avx2? ( cpu_flags_x86_avx )
    cpu_flags_x86_avx512f? ( cpu_flags_x86_avx2 )
    cpu_flags_x86_avx512vbmi? ( cpu_flags_x86_avx512f )
    cpu_flags_x86_avx512_vnni? ( cpu_flags_x86_avx512f )
    cpu_flags_x86_avx512_bf16? ( cpu_flags_x86_avx512f )
"

RDEPEND="
    acct-group/ollama
    acct-user/ollama
"

DEPEND="
    >=dev-lang/go-1.25.5
    >=dev-build/cmake-3.31.9
    >=sys-devel/gcc-11.5.0
    cuda? ( dev-util/nvidia-cuda-toolkit )
    video_cards_amdgpu? ( sci-libs/hipBLAS[${ROCM_USEDEP}] )
    systemd? ( sys-apps/systemd )
"

PATCHES=(
    "${FILESDIR}/${P}-vendor_update_b8187.patch"
)

src_prepare() {
    # patching hardcoded ../lib/ollama to use the native one
    sed -i \
        "s|filepath.Join(filepath.Dir(exe), \"..\", \"lib\", \"ollama\")|\"${EPREFIX}/usr/$(get_libdir)/ollama\"|" \
        ml/path.go || die
    sed -i "s|\"lib/ollama\"|\"$(get_libdir)/ollama\"|" \
        ml/backend/ggml/ggml/src/ggml.go || die

    # correcting version
    sed -i "s|0.0.0|${PV}|g" version/version.go || die

    cmake_src_prepare
}

src_configure() {
    local mycmakeargs=(
        -DGGML_CPU_ALL_VARIANTS=ON
        -DCMAKE_INSTALL_LIBDIR="$(get_libdir)"
        -DCMAKE_SKIP_BUILD_RPATH=ON
        -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON
        -DCMAKE_INSTALL_RPATH="\$ORIGIN"
    )
    

    # AMD (ROCm)
    use video_cards_amdgpu && \
        mycmakeargs+=(
            -DCMAKE_C_COMPILER=clang
            -DCMAKE_CXX_COMPILER=clang++
            -DCMAKE_DISABLE_FIND_PACKAGE_CUDAToolkit=ON
            -DAMDGPU_TARGETS="${AMDGPU_TARGETS// /;}"
        )
    
    # nVidia (CUDA)
    use cuda && \
        mycmakeargs+=(
            -DCMAKE_CUDA_ARCHITECTURES="75;80;86;89;90;90a"
            -DCMAKE_DISABLE_FIND_PACKAGE_hip=ON
        )

    cmake_src_configure
}


src_compile() {
    cmake_src_compile
    ego build -o ollama .
}

src_install() {
    dobin ollama

    insinto "/usr/$(get_libdir)/ollama"
    doins -r "${BUILD_DIR}/lib/ollama/"*

    dodir /etc/ld.so.conf.d
    echo "/usr/$(get_libdir)/ollama" > "${ED}/etc/ld.so.conf.d/ollama.conf"

    use systemd && systemd_dounit "${FILESDIR}/ollama.service"
}

pkg_preinst() {
    keepdir /var/log/ollama
    fowners ollama:ollama /var/log/ollama

    keepdir /var/lib/ollama/models
    fowners ollama:ollama /var/lib/ollama/models
}

pkg_postinst() {
    einfo "Quick guide:"
    einfo "systemctl start ollama"
    einfo "ollama run deepseek-r1:7b"
    einfo "See available models at https://ollama.com/library"
}
