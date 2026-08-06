# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake flag-o-matic systemd

DESCRIPTION="Fast and Lightweight Log processor and forwarder for Linux, BSD and OSX"
HOMEPAGE="http://fluentbit.io/"
SRC_URI="https://github.com/fluent/fluent-bit/archive/v${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="Apache-2.0"
SLOT="0"
KEYWORDS="~amd64 ~arm64"

# grep "option(FLB_IN_" CMakeLists.txt | awk -F "[( ]" '{ print "\x27" tolower(substr($2, 8)) "\x27" }' | sort | grep -v stdin
INPUT_PLUGINS_OPT=(
    'calyptia_fleet'
    'collectd'
    'cpu'
    'disk'
    'docker'
    'docker_events'
    'dummy'
    'elasticsearch'
    'emitter'
    'event_test'
    'event_test'
    'event_type'
    'exec'
    'exec_wasi'
    'fluentbit_metrics'
    'forward'
    'head'
    'health'
    'http'
    'kafka'
    'kmsg'
    'kubernetes_events'
    'lib'
    'mem'
    'mqtt'
    'netif'
    'nginx_exporter_metrics'
    'node_exporter_metrics'
    'opentelemetry'
    'podman_metrics'
    'proc'
    'prometheus_scrape'
    'random'
    'serial'
    'splunk'
    'statsd'
    'storage_backlog'
    'syslog'
    'systemd'
    'tail'
    'tcp'
    'thermal'
    'udp'
    'unix_socket'
    'windows_exporter_metrics'
    'winevtlog'
    'winlog'
    'winstat'
)
INPUT_PLUGINS_STD=(
    'stdin'
)
# grep "option(FLB_OUT_" CMakeLists.txt | awk -F "[( ]" '{ print "\x27" tolower(substr($2, 9)) "\x27" }' | sort | grep -Ev '(null|stdout)'
OUTPUT_PLUGINS_OPT=(
    'azure'
    'azure_blob'
    'azure_kusto'
    'azure_logs_ingestion'
    'bigquery'
    'calyptia'
    'chronicle'
    'cloudwatch_logs'
    'counter'
    'datadog'
    'es'
    'exit'
    'file'
    'flowcounter'
    'forward'
    'gelf'
    'http'
    'influxdb'
    'kafka'
    'kafka_rest'
    'kinesis_firehose'
    'kinesis_streams'
    'lib'
    'logdna'
    'loki'
    'nats'
    'nrlogs'
    'opensearch'
    'opentelemetry'
    'pgsql'
    'plot'
    'prometheus_exporter'
    'prometheus_remote_write'
    'retry'
    's3'
    'skywalking'
    'slack'
    'splunk'
    'stackdriver'
    'syslog'
    'tcp'
    'td'
    'udp'
    'vivo_exporter'
    'websocket'
)
OUTPUT_PLUGINS_STD=(
    'null'
    'stdout'
)
# grep "option(FLB_FILTER_" CMakeLists.txt | awk -F "[( ]" '{ print "\x27" tolower(substr($2, 12)) "\x27" }' | sort | grep -Ev '(grep|modify|nest|parser|record_modifier|stdout|throttle)'
FILTER_OPT=(
    'alter_size'
    'aws'
    'checklist'
    'ecs'
    'expect'
    'geoip2'
    'kubernetes'
    'log_to_metrics'
    'lua'
    'lua_use_mpack'
    'multiline'
    'nightfall'
    'rewrite_tag'
    'tensorflow'
    'type_converter'
    'wasm'
)
FILTER_STD=(
    'grep'
    'modify'
    'nest'
    'parser'
    'record_modifier'
    'stdout'
    'throttle'
)

IUSE="debug examples jemalloc luajit systemd +tls"
for plugin in ${INPUT_PLUGINS_OPT[@]}; do
    IUSE="${IUSE} fluentbit_input_plugins_${plugin}"
done
for plugin in ${INPUT_PLUGINS_STD[@]}; do
    IUSE="${IUSE} +fluentbit_input_plugins_${plugin}"
done
for plugin in ${OUTPUT_PLUGINS_STD[@]}; do
    IUSE="${IUSE} +fluentbit_output_plugins_${plugin}"
done
for plugin in ${OUTPUT_PLUGINS_OPT[@]}; do
    IUSE="${IUSE} fluentbit_output_plugins_${plugin}"
done
for filter in ${FILTER_STD[@]}; do
    IUSE="${IUSE} +fluentbit_filters_${filter}"
done
for filter in ${FILTER_OPT[@]}; do
    IUSE="${IUSE} fluentbit_filters_${filter}"
done

RESTRICT="mirror"

RDEPEND="acct-group/logger
    acct-user/${PN}
    luajit? ( dev-lang/luajit )
    jemalloc? ( dev-libs/jemalloc )
    fluentbit_output_plugins_pgsql? ( >=dev-db/postgresql-9.5:= )"
DEPEND="${RDEPEND}"

BUILD_DIR="${S}/build"
CMAKE_BUILD_TYPE="Release"
CMAKE_MAKEFILE_GENERATOR="emake"

QA_PREBUILT="
    usr/bin/fluent-bit
    usr/*/fluent-bit/libfluent-bit.so
"

src_configure() {
    append-cflags -fcommon -Wno-stringop-overflow -Wno-array-parameter
    local mycmakeargs=(
        -Wno-dev
        -DCMAKE_INSTALL_SYSCONFDIR="${EPREFIX}/etc"
        -DBUILD_SHARED_LIBS=no
        -DFLB_DEBUG="$(usex debug)"
        -DFLB_JEMALLOC="$(usex jemalloc)"
        -DFLB_TLS="$(usex tls)"
        -DFLB_EXAMPLES="$(usex examples)"
        -DFLB_BACKTRACE="$(usex debug)"
        -DFLB_LUAJIT="$(usex luajit)"
    )

    for plugin in ${INPUT_PLUGINS_STD}; do
        mycmakeargs+=("-DFLB_IN_${plugin^^}=$(usex fluentbit_input_plugins_${plugin})")
    done
    for plugin in ${INPUT_PLUGINS_OPT}; do
        mycmakeargs+=("-DFLB_IN_${plugin^^}=$(usex fluentbit_input_plugins_${plugin})")
    done
    for plugin in ${OUTPUT_PLUGINS_STD}; do
        mycmakeargs+=("-DFLB_OUT_${plugin^^}=$(usex fluentbit_output_plugins_${plugin})")
    done
    for plugin in ${OUTPUT_PLUGINS_OPT}; do
        mycmakeargs+=("-DFLB_OUT_${plugin^^}=$(usex fluentbit_output_plugins_${plugin})")
    done
    for filter in ${FILTER_STD}; do
        mycmakeargs+=("-DFLB_FILTER_${filter^^}=$(usex fluentbit_filters_${filter})")
    done
    for filter in ${FILTER_OPT}; do
        mycmakeargs+=("-DFLB_FILTER_${filter^^}=$(usex fluentbit_filters_${filter})")
    done

    cmake_src_configure
}

src_install() {
    cmake_src_install

    keepdir "/var/log/${PN}"

    newconfd "${FILESDIR}/${PN}.confd" "${PN}"
    newinitd "${FILESDIR}/${PN}.initd" "${PN}"
    use systemd && systemd_newunit "${FILESDIR}"/${PN}.service ${PN}.service

    fowners ${PN}:logger "/etc/${PN}"
}
