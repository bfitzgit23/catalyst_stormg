# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="OAuth2.0 + OpenID Connect Provider for Matrix Homeservers"
HOMEPAGE="https://github.com/element-hq/matrix-authentication-service"

CRATES="
    Inflector@0.11.4
    addr2line@0.24.2
    adler2@2.0.0
    aead@0.5.2
    aes-gcm@0.10.3
    aes@0.8.4
    ahash@0.8.11
    aho-corasick@1.1.3
    aide-macros@0.8.0
    aide@0.14.2
    allocator-api2@0.2.21
    android-tzdata@0.1.1
    android_system_properties@0.1.5
    anstream@0.6.18
    anstyle-parse@0.2.6
    anstyle-query@1.1.2
    anstyle-wincon@3.0.7
    anstyle@1.0.10
    anyhow@1.0.98
    arbitrary@1.4.1
    arc-swap@1.7.1
    argon2@0.5.3
    arrayvec@0.7.6
    as_variant@1.3.0
    assert-json-diff@2.0.2
    assert_matches@1.5.0
    async-channel@1.9.0
    async-channel@2.3.1
    async-executor@1.13.1
    async-global-executor@2.4.1
    async-graphql-derive@7.0.16
    async-graphql-parser@7.0.16
    async-graphql-value@7.0.16
    async-graphql@7.0.16
    async-io@2.4.0
    async-lock@3.4.0
    async-process@2.3.0
    async-signal@0.2.10
    async-std@1.13.1
    async-stream-impl@0.3.6
    async-stream@0.3.6
    async-task@4.7.1
    async-trait@0.1.88
    atoi@2.0.0
    atomic-waker@1.1.2
    atomic@0.6.0
    autocfg@1.4.0
    aws-lc-rs@1.13.0
    aws-lc-sys@0.28.0
    axum-core@0.5.2
    axum-extra@0.10.1
    axum-macros@0.5.0
    axum@0.8.3
    backtrace@0.3.74
    base16ct@0.2.0
    base64@0.21.7
    base64@0.22.1
    base64ct@1.7.3
    bcrypt@0.17.0
    bindgen@0.69.5
    bit-set@0.5.3
    bit-vec@0.6.3
    bitflags@2.9.0
    blake2@0.10.6
    block-buffer@0.10.4
    block-padding@0.3.3
    blocking@1.6.1
    blowfish@0.9.1
    bumpalo@3.17.0
    bytemuck@1.22.0
    byteorder@1.5.0
    bytes@1.10.1
    calendrical_calculations@0.1.2
    camino@1.1.9
    castaway@0.2.3
    cbc@0.1.2
    cc@1.2.18
    cesu8@1.1.0
    cexpr@0.6.0
    cfg-if@1.0.0
    cfg_aliases@0.2.1
    chacha20@0.9.1
    chacha20poly1305@0.10.1
    chrono-tz-build@0.4.1
    chrono-tz@0.10.3
    chrono@0.4.41
    chronoutil@0.2.7
    chumsky@0.9.3
    cipher@0.4.4
    clang-sys@1.8.1
    clap@4.5.37
    clap_builder@4.5.37
    clap_derive@4.5.32
    clap_lex@0.7.4
    cmake@0.1.54
    cobs@0.2.3
    colorchoice@1.0.3
    combine@4.6.7
    compact_str@0.9.0
    concurrent-queue@2.5.0
    console@0.15.11
    const-oid@0.9.6
    convert_case@0.8.0
    cookie@0.18.1
    cookie_store@0.21.1
    core-foundation-sys@0.8.7
    core-foundation@0.10.0
    core_maths@0.1.1
    cpufeatures@0.2.17
    cranelift-assembler-x64-meta@0.118.0
    cranelift-assembler-x64@0.118.0
    cranelift-bforest@0.118.0
    cranelift-bitset@0.118.0
    cranelift-codegen-meta@0.118.0
    cranelift-codegen-shared@0.118.0
    cranelift-codegen@0.118.0
    cranelift-control@0.118.0
    cranelift-entity@0.118.0
    cranelift-frontend@0.118.0
    cranelift-isle@0.118.0
    cranelift-native@0.118.0
    crc-catalog@2.4.0
    crc32fast@1.4.2
    crc@3.2.1
    cron@0.15.0
    crossbeam-channel@0.5.15
    crossbeam-deque@0.8.6
    crossbeam-epoch@0.9.18
    crossbeam-queue@0.3.12
    crossbeam-utils@0.8.21
    crypto-bigint@0.5.5
    crypto-common@0.1.6
    csv-core@0.1.12
    csv@1.3.1
    ctr@0.9.2
    darling@0.20.11
    darling_core@0.20.11
    darling_macro@0.20.11
    dashmap@6.1.0
    deadpool-runtime@0.1.4
    deadpool@0.10.0
    debugid@0.8.0
    der@0.7.10
    deranged@0.4.0
    derive_builder@0.20.2
    derive_builder_core@0.20.2
    derive_builder_macro@0.20.2
    dialoguer@0.11.0
    digest@0.10.7
    displaydoc@0.2.5
    document-features@0.2.11
    dotenvy@0.15.7
    dunce@1.0.5
    duration-str@0.12.0
    dyn-clone@1.0.19
    ecdsa@0.16.9
    either@1.15.0
    elliptic-curve@0.13.8
    email-encoding@0.4.0
    email_address@0.2.9
    embedded-io@0.4.0
    embedded-io@0.6.1
    encode_unicode@1.0.0
    encoding_rs@0.8.35
    equivalent@1.0.2
    errno@0.3.11
    etcetera@0.8.0
    event-listener-strategy@0.5.4
    event-listener@2.5.3
    event-listener@5.4.0
    fallible-iterator@0.3.0
    fancy-regex@0.13.0
    fastrand@2.3.0
    ff@0.13.1
    figment@0.10.19
    fixed_decimal@0.5.6
    flume@0.11.1
    fnv@1.0.7
    foldhash@0.1.5
    form_urlencoded@1.2.1
    fs_extra@1.3.0
    futures-channel@0.3.31
    futures-core@0.3.31
    futures-executor@0.3.31
    futures-intrusive@0.5.0
    futures-io@0.3.31
    futures-lite@2.6.0
    futures-macro@0.3.31
    futures-sink@0.3.31
    futures-task@0.3.31
    futures-timer@3.0.3
    futures-util@0.3.31
    futures@0.3.31
    fuzzy-matcher@0.3.7
    generic-array@0.14.7
    getrandom@0.2.15
    getrandom@0.3.2
    ghash@0.5.1
    gimli@0.31.1
    glob@0.3.2
    gloo-timers@0.3.0
    governor@0.10.0
    group@0.13.0
    h2@0.4.8
    hashbrown@0.12.3
    hashbrown@0.14.5
    hashbrown@0.15.2
    hashlink@0.10.0
    headers-core@0.3.0
    headers@0.4.0
    heck@0.4.1
    heck@0.5.0
    hermit-abi@0.3.9
    hermit-abi@0.4.0
    hex@0.4.3
    hkdf@0.12.4
    hmac@0.12.1
    home@0.5.11
    hostname@0.4.0
    http-body-util@0.1.3
    http-body@1.0.1
    http-range-header@0.4.2
    http@1.3.1
    httparse@1.10.1
    httpdate@1.0.3
    hyper-rustls@0.27.5
    hyper-util@0.1.11
    hyper@1.6.0
    iana-time-zone-haiku@0.1.2
    iana-time-zone@0.1.63
    icu_calendar@1.5.2
    icu_calendar_data@1.5.1
    icu_collections@1.5.0
    icu_datetime@1.5.1
    icu_datetime_data@1.5.1
    icu_decimal@1.5.0
    icu_decimal_data@1.5.1
    icu_experimental@0.1.0
    icu_experimental_data@0.1.1
    icu_locid@1.5.0
    icu_locid_transform@1.5.0
    icu_locid_transform_data@1.5.1
    icu_normalizer@1.5.0
    icu_normalizer_data@1.5.1
    icu_pattern@0.2.0
    icu_plurals@1.5.0
    icu_plurals_data@1.5.1
    icu_properties@1.5.1
    icu_properties_data@1.5.1
    icu_provider@1.5.0
    icu_provider_adapters@1.5.0
    icu_provider_macros@1.5.0
    icu_timezone@1.5.0
    icu_timezone_data@1.5.1
    id-arena@2.2.1
    ident_case@1.0.1
    idna@1.0.3
    idna_adapter@1.2.0
    indexmap@1.9.3
    indexmap@2.9.0
    indoc@2.0.6
    inherent@1.0.12
    inlinable_string@0.1.15
    inout@0.1.4
    insta@1.43.1
    ipnet@2.11.0
    ipnetwork@0.20.0
    is_terminal_polyfill@1.70.1
    itertools@0.12.1
    itertools@0.13.0
    itertools@0.14.0
    itoa@1.0.15
    jni-sys@0.3.0
    jni@0.21.1
    jobserver@0.1.33
    js-sys@0.3.77
    js_int@0.2.2
    json-patch@4.0.0
    jsonptr@0.7.1
    k256@0.13.4
    kv-log-macro@1.0.7
    language-tags@0.3.2
    lazy_static@1.5.0
    lazycell@1.3.0
    leb128fmt@0.1.0
    lettre@0.11.15
    libc@0.2.171
    libloading@0.8.6
    libm@0.2.11
    libsqlite3-sys@0.30.1
    linux-raw-sys@0.4.15
    listenfd@1.0.2
    litemap@0.7.5
    litrs@0.4.1
    lock_api@0.4.12
    log@0.4.27
    mach2@0.4.2
    matchers@0.1.0
    matchit@0.8.4
    md-5@0.10.6
    memchr@2.7.4
    memfd@0.6.4
    memo-map@0.3.3
    mime@0.3.17
    mime_guess@2.0.5
    minijinja-contrib@2.9.0
    minijinja@2.9.0
    minimal-lexical@0.2.1
    miniz_oxide@0.8.7
    mio@1.0.3
    multer@3.1.0
    nom@7.1.3
    nom@8.0.0
    nonzero_ext@0.3.0
    nu-ansi-term@0.46.0
    num-bigint-dig@0.8.4
    num-bigint@0.4.6
    num-conv@0.1.0
    num-integer@0.1.46
    num-iter@0.1.45
    num-rational@0.4.2
    num-traits@0.2.19
    num_cpus@1.16.0
    num_threads@0.1.7
    object@0.36.7
    once_cell@1.21.3
    opa-wasm@0.1.5
    opaque-debug@0.3.1
    openssl-probe@0.1.6
    opentelemetry-http@0.29.0
    opentelemetry-jaeger-propagator@0.29.0
    opentelemetry-otlp@0.29.0
    opentelemetry-prometheus@0.29.1
    opentelemetry-proto@0.29.0
    opentelemetry-resource-detectors@0.8.0
    opentelemetry-semantic-conventions@0.29.0
    opentelemetry-stdout@0.29.0
    opentelemetry@0.29.1
    opentelemetry_sdk@0.29.0
    os_info@3.10.0
    overload@0.1.1
    p256@0.13.2
    p384@0.13.1
    pad@0.1.6
    parking@2.2.1
    parking_lot@0.12.3
    parking_lot_core@0.9.10
    parse-size@1.1.0
    parse-zoneinfo@0.3.1
    password-hash@0.5.0
    paste@1.0.15
    pbkdf2@0.12.2
    pear@0.2.9
    pear_codegen@0.2.9
    pem-rfc7468@0.7.0
    percent-encoding@2.3.1
    pest@2.8.0
    pest_derive@2.8.0
    pest_generator@2.8.0
    pest_meta@2.8.0
    phf@0.11.3
    phf_codegen@0.11.3
    phf_generator@0.11.3
    phf_shared@0.11.3
    pin-project-internal@1.1.10
    pin-project-lite@0.2.16
    pin-project@1.1.10
    pin-utils@0.1.0
    piper@0.2.4
    pkcs1@0.7.5
    pkcs5@0.7.1
    pkcs8@0.10.2
    pkg-config@0.3.32
    polling@3.7.4
    poly1305@0.8.0
    polyval@0.6.2
    portable-atomic@1.11.0
    postcard@1.1.1
    powerfmt@0.2.0
    ppv-lite86@0.2.21
    prettyplease@0.2.32
    primeorder@0.13.6
    proc-macro-crate@3.2.0
    proc-macro2-diagnostics@0.10.1
    proc-macro2@1.0.94
    prometheus@0.14.0
    prost-derive@0.13.5
    prost@0.13.5
    protobuf-support@3.7.2
    protobuf@3.7.2
    psl-types@2.0.11
    psl@2.1.105
    psm@0.1.25
    pulley-interpreter@31.0.0
    quanta@0.12.5
    quinn-proto@0.11.10
    quinn-udp@0.5.11
    quinn@0.11.7
    quote@1.0.40
    quoted_printable@0.5.1
    r-efi@5.2.0
    rand@0.8.5
    rand@0.9.0
    rand_chacha@0.3.1
    rand_chacha@0.9.0
    rand_core@0.6.4
    rand_core@0.9.3
    raw-cpuid@11.5.0
    rayon-core@1.12.1
    rayon@1.10.0
    redox_syscall@0.5.11
    regalloc2@0.11.2
    regex-automata@0.1.10
    regex-automata@0.4.9
    regex-syntax@0.6.29
    regex-syntax@0.8.5
    regex@1.11.1
    reqwest@0.12.15
    rfc6979@0.4.0
    ring@0.17.14
    rsa@0.9.8
    ruma-common@0.15.2
    ruma-identifiers-validation@0.10.1
    ruma-macros@0.15.1
    rust_decimal@1.37.1
    rustc-demangle@0.1.24
    rustc-hash@1.1.0
    rustc-hash@2.1.1
    rustc_version@0.4.1
    rustix@0.38.44
    rustls-native-certs@0.8.1
    rustls-pemfile@2.2.0
    rustls-pki-types@1.11.0
    rustls-platform-verifier-android@0.1.1
    rustls-platform-verifier@0.5.2
    rustls-webpki@0.103.1
    rustls@0.23.26
    rustversion@1.0.20
    ryu@1.0.20
    salsa20@0.10.2
    same-file@1.0.6
    schannel@0.1.27
    schemars@0.8.22
    schemars_derive@0.8.22
    scopeguard@1.2.0
    scrypt@0.11.0
    sd-notify@0.4.5
    sea-query-binder@0.7.0
    sea-query-derive@0.4.3
    sea-query@0.32.4
    sec1@0.7.3
    security-framework-sys@2.14.0
    security-framework@3.2.0
    self_cell@1.1.0
    semver@1.0.26
    sentry-backtrace@0.37.0
    sentry-contexts@0.37.0
    sentry-core@0.37.0
    sentry-panic@0.37.0
    sentry-tower@0.37.0
    sentry-tracing@0.37.0
    sentry-types@0.37.0
    sentry@0.37.0
    serde@1.0.219
    serde_derive@1.0.219
    serde_derive_internals@0.29.1
    serde_html_form@0.2.7
    serde_json@1.0.140
    serde_path_to_error@0.1.17
    serde_qs@0.14.0
    serde_spanned@0.6.8
    serde_urlencoded@0.7.1
    serde_with@3.12.0
    serde_with_macros@3.12.0
    serde_yaml@0.9.34+deprecated
    sha1@0.10.6
    sha2@0.10.8
    sharded-slab@0.1.7
    shell-words@1.1.0
    shlex@1.3.0
    signal-hook-registry@1.4.2
    signature@2.2.0
    similar@2.7.0
    siphasher@1.0.1
    slab@0.4.9
    smallvec@1.15.0
    socket2@0.5.9
    spin@0.9.8
    spinning_top@0.3.0
    spki@0.7.3
    sprintf@0.4.0
    sptr@0.3.2
    sqlx-core@0.8.5
    sqlx-macros-core@0.8.5
    sqlx-macros@0.8.5
    sqlx-mysql@0.8.5
    sqlx-postgres@0.8.5
    sqlx-sqlite@0.8.5
    sqlx@0.8.5
    stable_deref_trait@1.2.0
    stacker@0.1.20
    static_assertions@1.1.0
    static_assertions_next@1.1.2
    stringprep@0.1.5
    strsim@0.11.1
    strum@0.26.3
    strum_macros@0.26.4
    subtle@2.6.1
    syn@2.0.100
    sync_wrapper@1.0.2
    synstructure@0.13.1
    target-lexicon@0.13.2
    tempfile@3.15.0
    termcolor@1.4.1
    thiserror-ext-derive@0.2.1
    thiserror-ext@0.2.1
    thiserror-impl@1.0.69
    thiserror-impl@2.0.12
    thiserror@1.0.69
    thiserror@2.0.12
    thread_local@1.1.8
    time-core@0.1.4
    time-macros@0.2.22
    time@0.3.41
    tinystr@0.7.6
    tinyvec@1.9.0
    tinyvec_macros@0.1.1
    tokio-macros@2.5.0
    tokio-rustls@0.26.2
    tokio-socks@0.5.2
    tokio-stream@0.1.17
    tokio-test@0.4.4
    tokio-util@0.7.15
    tokio@1.44.2
    toml@0.8.19
    toml_datetime@0.6.8
    toml_edit@0.22.22
    tonic@0.12.3
    tower-http@0.6.2
    tower-layer@0.3.3
    tower-service@0.3.3
    tower@0.5.2
    tracing-appender@0.2.3
    tracing-attributes@0.1.28
    tracing-core@0.1.33
    tracing-futures@0.2.5
    tracing-log@0.2.0
    tracing-opentelemetry@0.30.0
    tracing-subscriber@0.3.19
    tracing@0.1.41
    trait-variant@0.1.2
    try-lock@0.2.5
    typenum@1.18.0
    ucd-trie@0.1.7
    ulid@1.1.4
    uname@0.1.1
    uncased@0.9.10
    unicase@2.8.1
    unicode-bidi@0.3.18
    unicode-ident@1.0.18
    unicode-normalization@0.1.24
    unicode-properties@0.1.3
    unicode-segmentation@1.12.0
    unicode-width@0.1.14
    unicode-width@0.2.0
    unicode-xid@0.2.6
    universal-hash@0.5.1
    unsafe-libyaml@0.2.11
    untrusted@0.9.0
    url@2.5.4
    urlencoding@2.1.3
    utf16_iter@1.0.5
    utf8_iter@1.0.4
    utf8parse@0.2.2
    uuid@1.16.0
    v_htmlescape@0.15.8
    valuable@0.1.1
    value-bag@1.11.1
    vcpkg@0.2.15
    vergen-gitcl@1.0.8
    vergen-lib@0.1.6
    vergen@9.0.6
    version_check@0.9.5
    walkdir@2.5.0
    want@0.3.1
    wasi@0.11.0+wasi-snapshot-preview1
    wasi@0.14.2+wasi-0.2.4
    wasite@0.1.0
    wasm-bindgen-backend@0.2.100
    wasm-bindgen-futures@0.4.50
    wasm-bindgen-macro-support@0.2.100
    wasm-bindgen-macro@0.2.100
    wasm-bindgen-shared@0.2.100
    wasm-bindgen@0.2.100
    wasm-encoder@0.226.0
    wasmparser@0.226.0
    wasmprinter@0.226.0
    wasmtime-asm-macros@31.0.0
    wasmtime-component-macro@31.0.0
    wasmtime-component-util@31.0.0
    wasmtime-cranelift@31.0.0
    wasmtime-environ@31.0.0
    wasmtime-fiber@31.0.0
    wasmtime-jit-icache-coherence@31.0.0
    wasmtime-math@31.0.0
    wasmtime-slab@31.0.0
    wasmtime-versioned-export-macros@31.0.0
    wasmtime-wit-bindgen@31.0.0
    wasmtime@31.0.0
    web-sys@0.3.77
    web-time@1.1.0
    webpki-root-certs@0.26.8
    webpki-roots@0.26.8
    which@4.4.2
    whoami@1.6.0
    wildmatch@2.4.0
    winapi-i686-pc-windows-gnu@0.4.0
    winapi-util@0.1.9
    winapi-x86_64-pc-windows-gnu@0.4.0
    winapi@0.3.9
    windows-core@0.52.0
    windows-core@0.61.0
    windows-implement@0.60.0
    windows-interface@0.59.1
    windows-link@0.1.1
    windows-registry@0.4.0
    windows-result@0.3.2
    windows-strings@0.3.1
    windows-strings@0.4.0
    windows-sys@0.45.0
    windows-sys@0.48.0
    windows-sys@0.52.0
    windows-sys@0.59.0
    windows-targets@0.42.2
    windows-targets@0.48.5
    windows-targets@0.52.6
    windows-targets@0.53.0
    windows@0.52.0
    windows_aarch64_gnullvm@0.42.2
    windows_aarch64_gnullvm@0.48.5
    windows_aarch64_gnullvm@0.52.6
    windows_aarch64_gnullvm@0.53.0
    windows_aarch64_msvc@0.42.2
    windows_aarch64_msvc@0.48.5
    windows_aarch64_msvc@0.52.6
    windows_aarch64_msvc@0.53.0
    windows_i686_gnu@0.42.2
    windows_i686_gnu@0.48.5
    windows_i686_gnu@0.52.6
    windows_i686_gnu@0.53.0
    windows_i686_gnullvm@0.52.6
    windows_i686_gnullvm@0.53.0
    windows_i686_msvc@0.42.2
    windows_i686_msvc@0.48.5
    windows_i686_msvc@0.52.6
    windows_i686_msvc@0.53.0
    windows_x86_64_gnu@0.42.2
    windows_x86_64_gnu@0.48.5
    windows_x86_64_gnu@0.52.6
    windows_x86_64_gnu@0.53.0
    windows_x86_64_gnullvm@0.42.2
    windows_x86_64_gnullvm@0.48.5
    windows_x86_64_gnullvm@0.52.6
    windows_x86_64_gnullvm@0.53.0
    windows_x86_64_msvc@0.42.2
    windows_x86_64_msvc@0.48.5
    windows_x86_64_msvc@0.52.6
    windows_x86_64_msvc@0.53.0
    winnow@0.6.26
    wiremock@0.6.3
    wit-bindgen-rt@0.39.0
    wit-parser@0.226.0
    woothee@0.13.0
    write16@1.0.0
    writeable@0.5.5
    yansi@1.0.1
    yoke-derive@0.7.5
    yoke@0.7.5
    zerocopy-derive@0.7.35
    zerocopy-derive@0.8.24
    zerocopy@0.7.35
    zerocopy@0.8.24
    zerofrom-derive@0.1.6
    zerofrom@0.1.6
    zeroize@1.8.1
    zerotrie@0.1.3
    zerovec-derive@0.10.3
    zerovec@0.10.4
    zxcvbn@3.1.0
"

inherit cargo systemd

SRC_URI="
    https://github.com/element-hq/${PN}/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz
    https://vendors.simple-co.de/${PN}/${P}-vendor.tar.xz
    ${CARGO_CRATE_URIS}
"

LICENSE="AGPL-3.0"
SLOT="0"
KEYWORDS="~amd64 ~x86"
RESTRICT="test"

IUSE="+frontend +policies"
REQUIRED_USE="policies? ( frontend )"

BDEPEND="
    frontend? ( net-libs/nodejs[npm] )
    policies? ( net-misc/opa )
"
RDEPEND="
    acct-user/matrix-auth-svc
    acct-group/matrix-auth-svc
    >=dev-db/postgresql-16
"
DEPEND="
    ${BDEPEND}
    ${RDEPEND}
"

MY_CONF="/etc/mas/config.yaml"

src_configure() {
    cargo_src_configure
}

src_compile() {
    # npm build
    if use frontend; then
        cd frontend
        npm run build
        cd ..
    fi

    if use policies; then
        cd policies
        make
    fi

    cargo_gen_config
    cargo_src_compile
}

src_install() {
    exeinto /usr/bin
    doexe target/release/mas-cli

    insinto usr/share/${PN}
    doins -r templates
    doins -r translations

    if use frontend; then
        insinto usr/share/${PN}/frontend
        doins -r frontend/dist/*
    fi

    if use policies; then
        insinto usr/share/${PN}/policies
        doins policies/policy.wasm
    fi

    dodoc -r docs
    dodoc README.md

    ## services
    systemd_dounit ${FILESDIR}/mas-worker.service
    systemd_dounit ${FILESDIR}/mas-server.service

    # creating config-dir
    keepdir /etc/mas
}

pkg_postinst() {
    if [ ! -f "${EROOT}${MY_CONF}" ]; then
        einfo "It seems that this is a new installation, don't forget to run:"
        einfo "    emerge --config ${CATEGORY}/${PN}:${SLOT}"
    fi
}

pkg_config() {
    einfo "The setup documentation can be found at:"
    einfo "    https://element-hq.github.io/matrix-authentication-service/setup/index.html"
    einfo

    if [ -f "${EROOT}${MY_CONF}" ]; then
        ewarn "Existing configuration found at: ${EROOT}${MY_CONF}"

        # TODO: should respect config (connection)!
        if $(su - postgres -c "psql -h localhost -c 'select 1' > /dev/null 2>&1"); then
            ewarn "    preforming migration .."
            mas-cli -c "${EROOT}${MY_CONF}" database migrate || die "database migration failed!"
            ewarn "    done!"
        fi

        return
    fi

    einfo "Generating configuraiton..."

    /usr/bin/mas-cli config generate -o "${EROOT}${MY_CONF}" > /dev/null 2>&1 || die "Couldn't generate config!"

    einfo "Creating database .."
    einfo "Checking if postfix is running .."

    if $(su - postgres -c "psql -h localhost -c 'select 1' > /dev/null 2>&1"); then
        einfo "    local instance found!"
        einfo "    creating user and db .."
    
        MY_DBPW=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w ${1:-32} | head -n 1);
        su - postgres -c "psql -q -c \"CREATE USER mas WITH PASSWORD '${MY_DBPW}';\" && createdb --owner=mas mas" \
            || die "couldn't create user/db!"

        einfo "    user and db succesfully created!"
        einfo "    patching config .."

        sed -i "s/  uri: postgresql:.*/  uri: postgresql:\/\/mas:${MY_DBPW}@localhost\/mas/" "${EROOT}${MY_CONF}" \
            || die "couldn't patch config!"
        
        einfo "    migrating database (initial) .."
    
        /usr/bin/mas-cli -c "${EROOT}${MY_CONF}" database migrate || die "database migration failed!"

        einfo "    all done! Database is ready to use!"
    else
        ewarn "    NO running local postgres instance found"
        ewarn ".. skipping database-setup!"
    fi

    einfo
    einfo "Adjusting config paths (assets, template, manifes, etc.) .."

    # templates, manifest and translations
    echo -e "templates:\n  path: /usr/share/${PN}/templates" >> "${EROOT}${MY_CONF}"
    echo -e "  assets_manifest: /usr/share/${PN}/frontend/manifest.json" >> "${EROOT}${MY_CONF}"
    echo -e "  translations_path: /usr/share/${PN}/translations" >> "${EROOT}${MY_CONF}"

    # assets
    sed -i "s/    - name: assets/    - name: assets\n      path: \/usr\/share\/${PN}\/frontend\//" "${EROOT}${MY_CONF}" \
        || die "couldn't patch config!"
    # policy
    echo -e "policy:\n  wasm_module: /usr/share/${PN}/policies/policy.wasm" >> "${EROOT}${MY_CONF}"

    einfo "    done. Config is ready to go."
    einfo
    einfo "Please check you configuration before starting the services at:"
    einfo "    ${EROOT}${MY_CONF}"
}