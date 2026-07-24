# ============================================================
# WPE WebKit 浏览器插件 — CMake 构建（for GitHub Actions CI）
# 本地构建使用 xmake.lua，CI 交叉编译使用此 CMakeLists.txt
# ============================================================
cmake_minimum_required(VERSION 3.16)
project(wpewebkit_browser LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Qt5（CI 环境使用系统 Qt5）
find_package(Qt5 REQUIRED COMPONENTS Core Quick Gui Qml)

# WPE WebKit / EGL / GLES（交叉编译产物位于 CMAKE_FIND_ROOT_PATH）
find_library(WPE_LIB wpe-1.0)
find_library(WPEBACKEND_LIB WPEBackend-fdo-1.0)
find_library(WPEWEBKIT_LIB wpewebkit-2.0)
find_library(EGL_LIB EGL)
find_library(GLESv2_LIB GLESv2)
find_library(GOBJECT_LIB gobject-2.0)
find_library(GLIB_LIB glib-2.0)

# EGL 头文件路径
find_path(EGL_INCLUDE_DIR EGL/egl.h)
find_path(GLES2_INCLUDE_DIR GLES2/gl2.h)

# 源文件（Qt MOC 自动处理）
set(SOURCES
    src/WebViewItem.cpp
    src/plugin.cpp
)

set(HEADERS
    src/WebViewItem.h
)

# 自动运行 MOC
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

# 构建目标
add_library(wpewebkit_browser SHARED ${SOURCES} ${HEADERS})

target_include_directories(wpewebkit_browser PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/src
    ${EGL_INCLUDE_DIR}
    ${GLES2_INCLUDE_DIR}
    ${Qt5Core_INCLUDE_DIRS}
    ${Qt5Quick_INCLUDE_DIRS}
)

target_link_libraries(wpewebkit_browser PRIVATE
    Qt5::Core Qt5::Quick Qt5::Gui Qt5::Qml
    ${WPE_LIB}
    ${WPEBACKEND_LIB}
    ${WPEWEBKIT_LIB}
    ${EGL_LIB}
    ${GLESv2_LIB}
    ${GOBJECT_LIB}
    ${GLIB_LIB}
)

# 输出文件名
set_target_properties(wpewebkit_browser PROPERTIES
    LIBRARY_OUTPUT_NAME wpewebkit_browser
    PREFIX "lib"
    SUFFIX ".so"
)

# 安装规则
install(TARGETS wpewebkit_browser
    LIBRARY DESTINATION lib
)
