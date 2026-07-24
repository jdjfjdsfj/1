#!/bin/bash
# ============================================================
# WPE WebKit 浏览器插件 — 交叉编译脚本
# 运行环境: WSL2 Archlinux (本机: Archlinux in WSL2)
# 目标设备: ARM Cortex-A35 (aarch64), Linux 4.4.159
# 目标 GCC: Linaro GCC 6.3.1 (ABI 兼容)
# ============================================================
set -euo pipefail

# ---------- 配置 ----------
TARGET_ARCH="aarch64"
TARGET_TRIPLET="${TARGET_ARCH}-linux-gnu"
TOOLCHAIN_DIR="$HOME/wpe-toolchain"
SYSROOT="$HOME/wpe-sysroot"
BUILD_DIR="$HOME/wpe-build"
PREFIX="$HOME/wpe-install"          # 编译产物安装到此
DEVICE_PREFIX="/userdisk/PenMods/wpe-libs"  # 设备上的部署路径

# 设备 sysroot（从设备拉取已有库，避免全部自编译）
DEVICE_SYSROOT="$HOME/wpe-device-sysroot"

# 并行编译数
JOBS=${JOBS:-$(nproc 2>/dev/null || echo 4)}

# ADB（WSL 中调用 Windows 宿主 adb.exe）
ADB="adb.exe"

# ----------------------------------------
# 各组件版本（锁定版本以保证兼容性）
# ----------------------------------------
PKG_SQLITE="https://www.sqlite.org/2024/sqlite-autoconf-3450200.tar.gz"       # 3.45.2
PKG_LIBXSLT="https://download.gnome.org/sources/libxslt/1.1/libxslt-1.1.42.tar.xz"
PKG_LIBSOUP="https://download.gnome.org/sources/libsoup/2.74/libsoup-2.74.3.tar.xz"
PKG_LIBWPE="https://github.com/WebPlatformForEmbedded/libwpe/archive/refs/tags/1.16.0.tar.gz"
PKG_WPEBACKEND_FDO="https://github.com/Igalia/WPEBackend-fdo/archive/refs/tags/1.14.3.tar.gz"
PKG_WPEWEBKIT="https://github.com/WebPlatformForEmbedded/WPEWebKit/archive/refs/tags/wpewebkit-2.44.2.tar.gz"

# ----------------------------------------
# 辅助函数
# ----------------------------------------
log()   { echo -e "\n\033[1;32m[WPE-BUILD]\033[0m $*"; }
warn()  { echo -e "\033[1;33m[WARN]\033[0m $*"; }
err()   { echo -e "\033[1;31m[ERROR]\033[0m $*" >&2; exit 1; }

check_adb() {
    if ! $ADB devices 2>/dev/null | grep -q "device$"; then
        warn "ADB 设备未连接，跳过 device 相关操作"
        return 1
    fi
    return 0
}

# 下载 + 解压
fetch_and_extract() {
    local url="$1" dest="$2"
    local fname="${url##*/}"
    mkdir -p "$BUILD_DIR"
    if [ ! -f "$BUILD_DIR/$fname" ]; then
        log "下载: $fname"
        curl -L --retry 3 -o "$BUILD_DIR/$fname" "$url"
    fi
    rm -rf "$dest"
    mkdir -p "$dest"
    log "解压: $fname -> $dest"
    tar -xf "$BUILD_DIR/$fname" -C "$dest" --strip-components=1
}

# cmake 交叉编译通用函数
cmake_cross_build() {
    local name="$1" srcdir="$2" extra_opts="${3:-}"
    local buildd="$srcdir/build"

    log "=== 交叉编译 $name ==="
    mkdir -p "$buildd"
    cmake -S "$srcdir" -B "$buildd" \
        -DCMAKE_SYSTEM_NAME=Linux \
        -DCMAKE_SYSTEM_PROCESSOR="$TARGET_ARCH" \
        -DCMAKE_C_COMPILER="$TOOLCHAIN_DIR/bin/${TARGET_TRIPLET}-gcc" \
        -DCMAKE_CXX_COMPILER="$TOOLCHAIN_DIR/bin/${TARGET_TRIPLET}-g++" \
        -DCMAKE_FIND_ROOT_PATH="$PREFIX" \
        -DCMAKE_INSTALL_PREFIX="$PREFIX" \
        -DBUILD_SHARED_LIBS=ON \
        -DCMAKE_BUILD_TYPE=Release \
        $extra_opts

    cmake --build "$buildd" -j"$JOBS"
    cmake --install "$buildd"
}

# meson 交叉编译通用函数
meson_cross_build() {
    local name="$1" srcdir="$2" extra_opts="${3:-}"
    local buildd="$srcdir/build"

    log "=== 交叉编译 $name ==="
    if [ -d "$buildd" ]; then rm -rf "$buildd"; fi
    mkdir -p "$buildd"

    # 生成交叉编译描述文件
    local crossfile="$srcdir/cross.txt"
    cat > "$crossfile" <<-EOF
[binaries]
c = '$TOOLCHAIN_DIR/bin/${TARGET_TRIPLET}-gcc'
cpp = '$TOOLCHAIN_DIR/bin/${TARGET_TRIPLET}-g++'
ar = '$TOOLCHAIN_DIR/bin/${TARGET_TRIPLET}-ar'
strip = '$TOOLCHAIN_DIR/bin/${TARGET_TRIPLET}-strip'
pkgconfig = 'pkg-config'

[properties]
sys_root = '$PREFIX'
pkg_config_libdir = '$PREFIX/lib/pkgconfig:$PREFIX/share/pkgconfig'

[host_machine]
system = 'linux'
cpu_family = 'aarch64'
cpu = 'aarch64'
endian = 'little'
EOF

    meson setup "$buildd" "$srcdir" \
        --cross-file="$crossfile" \
        --prefix="$PREFIX" \
        --buildtype=release \
        --default-library=shared \
        -Dpkg_config_path="$PREFIX/lib/pkgconfig:$PREFIX/share/pkgconfig" \
        $extra_opts

    ninja -C "$buildd" -j"$JOBS"
    DESTDIR=/ ninja -C "$buildd" install
}

# ============================================================
# Step 0: 安装交叉编译工具链
# ============================================================
setup_toolchain() {
    log "=== Step 0: 安装 aarch64 交叉编译工具链 ==="

    # 方法1: 使用 Arch AUR 的 aarch64-linux-gnu-gcc
    if command -v yay &>/dev/null; then
        log "通过 yay 安装 aarch64-linux-gnu-gcc..."
        yay -S --noconfirm aarch64-linux-gnu-gcc aarch64-linux-gnu-binutils 2>/dev/null || true
    fi

    # 方法2: 直接使用 pacman 的社区包（通常需要启用 multilib）
    log "通过 pacman 安装交叉编译工具链..."
    sudo pacman -S --needed --noconfirm \
        aarch64-linux-gnu-gcc \
        aarch64-linux-gnu-binutils \
        aarch64-linux-gnu-glibc \
        aarch64-linux-gnu-linux-api-headers 2>/dev/null || true

    # 验证
    if ! command -v aarch64-linux-gnu-gcc &>/dev/null; then
        err "aarch64-linux-gnu-gcc 未安装。请手动安装：\n\
             sudo pacman -S aarch64-linux-gnu-gcc\n\
             或从 https://releases.linaro.org 下载 Linaro 工具链"
    fi

    TOOLCHAIN_DIR="/usr"
    log "交叉编译器: $(aarch64-linux-gnu-gcc --version | head -1)"
}

# ============================================================
# Step 1: 安装构建依赖
# ============================================================
setup_build_deps() {
    log "=== Step 1: 安装构建依赖 ==="
    sudo pacman -S --needed --noconfirm \
        base-devel git wget curl \
        cmake meson ninja pkg-config \
        python python-pip python-jinja \
        perl ruby \
        gperf bison flex \
        wayland wayland-protocols \
        gobject-introspection \
        glib2 \
        libxkbcommon \
        2>/dev/null || true
}

# ============================================================
# Step 2: 拉取设备 sysroot（已有库作为交叉编译 base）
# ============================================================
pull_device_sysroot() {
    log "=== Step 2: 从设备拉取已有库作为 sysroot ==="
    if ! check_adb; then
        warn "跳过拉取设备库"
        return
    fi

    mkdir -p "$DEVICE_SYSROOT/usr/lib" "$DEVICE_SYSROOT/usr/include"

    # 拉取设备上的关键库（有 so 无头的不行，尝试拉 .h 或假装）
    log "拉取设备共享库..."
    for lib in libEGL.so libGLESv2.so libglib-2.0.so libgobject-2.0.so \
               libgio-2.0.so libcairo.so libpng16.so libjpeg.so libxml2.so \
               libQt5Core.so libQt5Quick.so libQt5Qml.so libQt5Gui.so; do
        $ADB pull "/usr/lib/$lib" "$DEVICE_SYSROOT/usr/lib/" 2>/dev/null || warn "  $lib 不存在于设备"
    done

    # 复制目录结构（lib 已有 .so 的就够了）
    ln -sf "$DEVICE_SYSROOT" "$SYSROOT" 2>/dev/null || true

    log "设备 sysroot 准备完毕: $DEVICE_SYSROOT"
}

# ============================================================
# Step 3: 交叉编译 sqlite3
# ============================================================
build_sqlite() {
    log "=== Step 3: 编译 sqlite3 ==="
    fetch_and_extract "$PKG_SQLITE" "$BUILD_DIR/sqlite"

    local srcdir="$BUILD_DIR/sqlite"
    cd "$srcdir"

    ${TARGET_TRIPLET}-gcc -c sqlite3.c -DSQLITE_ENABLE_FTS5 -DSQLITE_ENABLE_JSON1 -O2 -fPIC
    ${TARGET_TRIPLET}-gcc -shared -o libsqlite3.so.0 sqlite3.o -lpthread -ldl -lm

    mkdir -p "$PREFIX/lib" "$PREFIX/include"
    cp libsqlite3.so.0 "$PREFIX/lib/"
    ln -sf libsqlite3.so.0 "$PREFIX/lib/libsqlite3.so"
    cp sqlite3.h sqlite3ext.h "$PREFIX/include/"
    log "sqlite3 编译完成"
}

# ============================================================
# Step 4: 交叉编译 libxslt
# ============================================================
build_libxslt() {
    log "=== Step 4: 编译 libxslt ==="
    fetch_and_extract "$PKG_LIBXSLT" "$BUILD_DIR/libxslt"

    local srcdir="$BUILD_DIR/libxslt"

    # libxslt 依赖 libxml2（设备已有，直接用）
    meson_cross_build "libxslt" "$srcdir" \
        -Dcrypto=false \
        -Dpython=false \
        -Dtests=false
}

# ============================================================
# Step 5: 交叉编译 libsoup2
# ============================================================
build_libsoup() {
    log "=== Step 5: 编译 libsoup2 ==="
    fetch_and_extract "$PKG_LIBSOUP" "$BUILD_DIR/libsoup"

    local srcdir="$BUILD_DIR/libsoup"
    meson_cross_build "libsoup" "$srcdir" \
        -Dtls_check=false \
        -Dgssapi=disabled \
        -Dsysprof=disabled \
        -Dtests=false \
        -Dintrospection=disabled \
        -Dvapi=disabled
}

# ============================================================
# Step 6: 交叉编译 libwpe
# ============================================================
build_libwpe() {
    log "=== Step 6: 编译 libwpe ==="
    fetch_and_extract "$PKG_LIBWPE" "$BUILD_DIR/libwpe"

    local srcdir="$BUILD_DIR/libwpe"
    meson_cross_build "libwpe" "$srcdir"
}

# ============================================================
# Step 7: 交叉编译 wpebackend-fdo
# ============================================================
build_wpebackend_fdo() {
    log "=== Step 7: 编译 wpebackend-fdo ==="
    fetch_and_extract "$PKG_WPEBACKEND_FDO" "$BUILD_DIR/wpebackend-fdo"

    local srcdir="$BUILD_DIR/wpebackend-fdo"
    cmake_cross_build "wpebackend-fdo" "$srcdir"
}

# ============================================================
# Step 8: 交叉编译 WPE WebKit（核心，最大最慢）
# ============================================================
build_wpewebkit() {
    log "=== Step 8: 编译 WPE WebKit（耗时最长，预计 1-4 小时） ==="
    fetch_and_extract "$PKG_WPEWEBKIT" "$BUILD_DIR/wpewebkit"

    local srcdir="$BUILD_DIR/wpewebkit"
    local buildd="$srcdir/WebKitBuild/Release"

    mkdir -p "$buildd"

    # WebKit 使用 CMake
    # 注意：禁用一切不需要的特性减小体积
    cmake -S "$srcdir" -B "$buildd" \
        -DCMAKE_SYSTEM_NAME=Linux \
        -DCMAKE_SYSTEM_PROCESSOR="$TARGET_ARCH" \
        -DCMAKE_C_COMPILER="${TARGET_TRIPLET}-gcc" \
        -DCMAKE_CXX_COMPILER="${TARGET_TRIPLET}-g++" \
        -DCMAKE_FIND_ROOT_PATH="$PREFIX" \
        -DCMAKE_INSTALL_PREFIX="$PREFIX" \
        -DCMAKE_BUILD_TYPE=Release \
        -DPORT=WPE \
        \
        `# 禁用不需要的功能以减小体积和编译时间` \
        -DENABLE_ACCELERATED_2D_CANVAS=OFF \
        -DENABLE_BUBBLEWRAP_SANDBOX=OFF \
        -DENABLE_DOCUMENTATION=OFF \
        -DENABLE_FULLSCREEN_API=ON \
        -DENABLE_GAMEPAD=OFF \
        -DENABLE_GEOLOCATION=OFF \
        -DENABLE_GLES2=ON \
        -DENABLE_GTKDOC=OFF \
        -DENABLE_INTROSPECTION=OFF \
        -DENABLE_JIT=OFF \
        -DENABLE_MINIBROWSER=OFF \
        -DENABLE_NOTIFICATIONS=OFF \
        -DENABLE_SAMPLING_PROFILER=OFF \
        -DENABLE_SPELLCHECK=OFF \
        -DENABLE_TOUCH_EVENTS=ON \
        -DENABLE_VIDEO=ON \
        -DENABLE_WAYLAND_TARGET=ON \
        -DENABLE_WEBDRIVER=OFF \
        -DENABLE_WEB_AUDIO=OFF \
        -DENABLE_WEB_CRYPTO=OFF \
        -DENABLE_XSLT=ON \
        \
        -DUSE_ANGLE_EGL=OFF \
        -DUSE_AVIF=OFF \
        -DUSE_EGL=ON \
        -DUSE_GSTREAMER_GL=ON \
        -DUSE_GSTREAMER_TRANSCODER=OFF \
        -DUSE_GSTREAMER_WEBRTC=OFF \
        -DUSE_JPEGXL=OFF \
        -DUSE_LCMS=OFF \
        -DUSE_LIBDRM=ON \
        -DUSE_LIBHYPHEN=OFF \
        -DUSE_LIBSECRET=OFF \
        -DUSE_LIBWPE=ON \
        -DUSE_OPENGL_OR_ES=ON \
        -DUSE_OPENJPEG=OFF \
        -DUSE_SOUP2=ON \
        -DUSE_SYSTEM_MALLOC=ON \
        -DUSE_WOFF2=OFF \
        -DUSE_WPEBACKEND_FDO=ON \
        \
        -Wno-dev

    # 编译（非常耗时）
    log "开始编译 WPE WebKit，这将持续一段时间..."
    cmake --build "$buildd" -j"$JOBS" 2>&1 | tee "$srcdir/build.log"

    log "安装..."
    cmake --install "$buildd"

    log "WPE WebKit 编译完成！"
    ls -la "$PREFIX/lib/libWPEWebKit-"* "$PREFIX/lib/libwpe"*
}

# ============================================================
# Step 9: 打包并部署到设备
# ============================================================
deploy_to_device() {
    log "=== Step 9: 部署到设备 ==="
    if ! check_adb; then
        err "未检测到 ADB 设备"
    fi

    local device_libdir="/userdisk/PenMods/wpe-libs"

    # 清理设备上旧库
    $ADB shell "rm -rf $device_libdir; mkdir -p $device_libdir"

    log "推送 .so 文件到设备..."
    $ADB push "$PREFIX/lib/"*.so "$PREFIX/lib/"*.so.* "$device_libdir/" 2>/dev/null || true

    # 设置库路径
    log "设置 LD_LIBRARY_PATH..."
    $ADB shell "echo 'export LD_LIBRARY_PATH=$device_libdir:\$LD_LIBRARY_PATH' >> /userdisk/.profile"

    log "部署完成！设备库路径: $device_libdir"
    $ADB shell "ls -la $device_libdir/"
}

# ============================================================
# Step 10: 编译我们自己的 .so 插件
# ============================================================
build_plugin() {
    log "=== Step 10: 编译 WPE 浏览器插件 ==="
    local plugin_src="$HOME/wpewebkit-browser-src"

    if [ ! -d "$plugin_src" ]; then
        warn "插件源码目录不存在: $plugin_src"
        warn "请将 wpewebkit-browser-src/ 复制到 WSL 中: $plugin_src"
        return
    fi

    cd "$plugin_src"

    # 设置 pkg-config 搜索路径
    export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig:$PREFIX/share/pkgconfig:$PKG_CONFIG_PATH"
    export LD_LIBRARY_PATH="$PREFIX/lib:$LD_LIBRARY_PATH"

    # 使用 xmake 构建
    if command -v xmake &>/dev/null; then
        xmake f -p linux -a arm64-v8a \
            --toolchain="${TARGET_TRIPLET}" \
            --sdk="$PREFIX"
        xmake build -j"$JOBS"
    fi

    # 复制产物到插件目录
    cp build/linux/arm64-v8a/release/libwpewebkit_browser.so \
        "$HOME/wpewebkit-browser/" 2>/dev/null || true

    log "插件编译完成"
}

# ============================================================
# 主入口
# ============================================================
main() {
    local step="${1:-all}"

    case "$step" in
        all)
            setup_toolchain
            setup_build_deps
            pull_device_sysroot
            build_sqlite
            build_libsoup
            build_libxslt
            build_libwpe
            build_wpebackend_fdo
            build_wpewebkit
            deploy_to_device
            build_plugin
            ;;
        toolchain)    setup_toolchain ;;
        deps)         setup_build_deps ;;
        sysroot)      pull_device_sysroot ;;
        sqlite)       build_sqlite ;;
        libsoup)      build_libsoup ;;
        libxslt)      build_libxslt ;;
        libwpe)       build_libwpe ;;
        backend)      build_wpebackend_fdo ;;
        webkit)       build_wpewebkit ;;
        deploy)       deploy_to_device ;;
        plugin)       build_plugin ;;
        *)
            echo "用法: $0 [step]"
            echo "  all       全部构建"
            echo "  toolchain 安装交叉编译工具链"
            echo "  deps      安装构建依赖"
            echo "  sqlite    libsoup  libxslt  libwpe  backend  webkit"
            echo "  deploy    部署到设备"
            echo "  plugin    编译插件 .so"
            ;;
    esac
}

main "$@"
