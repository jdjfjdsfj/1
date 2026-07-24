-- ============================================================
-- WPE WebKit 浏览器插件 — xmake 构建脚本
--
-- 交叉编译目标: ARM Cortex-A35 (Rockchip SoC)
-- 产物: libwpewebkit_browser.so
-- ============================================================

set_project("wpewebkit-browser")
set_version("1.0.0")
set_languages("c++17")

-- 构建设置
set_warnings("all")
set_optimize("fastest")

-- Qt shared 规则（生成 .so）
add_rules("qt.shared")

-- 目标
target("wpewebkit_browser")
    set_kind("shared")
    set_filename("libwpewebkit_browser.so")

    -- Qt 5 框架
    add_frameworks("Qt5Core", "Qt5Quick", "Qt5Gui", "Qt5Qml")

    -- WPE / WebKit 依赖
    -- 设备上通过 pkg-config 获取编译参数
    add_packages("wpe-1.0", {optional = false})
    add_packages("wpebackend-fdo-1.0", {optional = false})
    add_packages("wpewebkit-2.0", {optional = false})

    -- EGL / GLES2（嵌入式 GPU 渲染）
    add_packages("egl", {optional = false})
    add_packages("glesv2", {optional = false})

    -- GLib（WebKit GObject 绑定需要）
    add_packages("glib-2.0", {optional = false})

    -- 源文件
    add_files("src/WebViewItem.cpp")
    add_files("src/plugin.cpp")

    -- 头文件（用于 MOC 处理）
    add_headerfiles("src/WebViewItem.h")

    -- 包含路径
    add_includedirs("src")

    -- 如果设备上的 WPE WebKit 包名不同，可在此覆盖：
    -- 常见变体: wpe-webkit-1.0, wpewebkit-1.0, wpe-2.0
    -- 取消下面的注释并调整:
    --
    -- remove_packages("wpewebkit-2.0")
    -- add_packages("wpe-webkit-1.0", {optional = false})
    --
    -- 如果完全不用 pkg-config，手动指定:
    --
    -- add_links("wpe-1.0", "WPEBackend-fdo-1.0", "wpewebkit-2.0")
    -- add_links("EGL", "GLESv2", "glib-2.0", "gobject-2.0")
