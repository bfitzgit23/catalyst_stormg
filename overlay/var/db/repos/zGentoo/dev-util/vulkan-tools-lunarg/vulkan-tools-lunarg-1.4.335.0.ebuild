# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2
EAPI=8

_PN=$(_PN=${PN%-*};_PN=${_PN//-/};_PN=${_PN//t/T};echo ${_PN^})

inherit cmake

DESCRIPTION="Vulkan Ecosystem Tools by LunarG"
HOMEPAGE="https://github.com/LunarG/VulkanTools/"
SRC_URI="
    https://github.com/LunarG/${_PN}/archive/vulkan-sdk-${PV}.tar.gz -> ${P}.tar.gz
"

LICENSE="Apache-2.0"
KEYWORDS="~amd64"
SLOT="0"

IUSE="-qt5 qt6"
REQUIRED_USE="^^ ( qt5 qt6 )"
S="${WORKDIR}"/${_PN}-vulkan-sdk-${PV}

RESTRICT="test" # TODO: (not yet tested)

DEPEND="
    dev-cpp/valijson
    ~dev-util/vulkan-headers-$PV
    ~dev-util/vulkan-utility-libraries-$PV
    ~media-libs/vulkan-loader-$PV
"
RDEPEND="${DEPEND}"
BDEPEND="
    dev-libs/jsoncpp:=
    qt5? (
        dev-qt/qtcore:5
        dev-qt/qtgui:5
        dev-qt/qtnetwork:5
        dev-qt/qtwidgets:5
    )
    qt6? (
        dev-qt/qtbase:6[gui,network,widgets]
    )
"

QA_SONAME="
    usr/lib64/libVkLayer_api_dump.so
    usr/lib64/libVkLayer_monitor.so
    usr/lib64/libVkLayer_screenshot.so
"

src_prepare() {
    ## removing internally used valijson to make use of the system-wide one
    sed -i '/find_package(valijson REQUIRED CONFIG)/d' CMakeLists.txt || die
    sed -i 's/valijson Qt/Qt/' vkconfig_core/CMakeLists.txt || die

    cmake_src_prepare
}
