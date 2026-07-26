set_project("wpewebkit-browser")
set_version("1.0.0")
set_languages("c++17")

set_warnings("all")

add_rules("qt.shared")

target("wpewebkit_browser")
    set_kind("shared")
    set_filename("libwpewebkit_browser.so")

    add_frameworks("Qt5Core", "Qt5Quick", "Qt5Gui", "Qt5Qml")

    -- WPE 依赖（从 build-deps job 产物中的 pkg-config 查找）
    add_packages("wpe-1.0", {optional = false})
    add_packages("wpebackend-fdo-1.0", {optional = false})

    -- 运行时依赖（可选，设备上已有）
    add_packages("egl", {optional = true})
    add_packages("glesv2", {optional = true})
    add_packages("glib-2.0", {optional = true})

    -- 如果 pkg-config 找不到，手动指定链接
    if not has_package("wpe-1.0") then
        add_links("wpe-1.0")
        add_linkdirs("$(env INSTALL_PREFIX)/lib")
        add_includedirs("$(env INSTALL_PREFIX)/include/wpe-1.0")
    end
    if not has_package("wpebackend-fdo-1.0") then
        add_links("WPEBackend-fdo-1.0")
        add_linkdirs("$(env INSTALL_PREFIX)/lib")
        add_includedirs("$(env INSTALL_PREFIX)/include/wpe-fdo-1.0")
    end

    add_links("EGL", "GLESv2", "gobject-2.0", "glib-2.0")

    add_files("src/WebViewItem.cpp")
    add_files("src/plugin.cpp")
    add_headerfiles("src/WebViewItem.h")
    add_includedirs("src")
    add_includedirs("$(env INSTALL_PREFIX)/include")
