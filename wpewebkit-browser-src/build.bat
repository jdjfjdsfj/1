@echo off
REM ============================================================
REM WPE WebKit 交叉编译 — Windows 启动脚本
REM 将源码复制到 WSL2 Archlinux 并启动 cross-build.sh
REM ============================================================
setlocal enabledelayedexpansion

set WSL_DISTRO=archlinux
set WSL_HOME=\\wsl.localhost\%WSL_DISTRO%\home\%USERNAME%
set PLUGIN_SRC=%~dp0

echo ========================================
echo   WPE WebKit 交叉编译启动器
echo ========================================
echo.
echo   WSL 发行版: %WSL_DISTRO%
echo   插件源码:   %PLUGIN_SRC%
echo.

REM Step 1: 确保 WSL 已启动
echo [1/4] 检查 WSL 状态...
wsl -d %WSL_DISTRO% -e echo "WSL ready" >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] WSL 未就绪，请先运行: wsl -d %WSL_DISTRO%
    pause
    exit /b 1
)

REM Step 2: 复制源码到 WSL
echo [2/4] 复制源码到 WSL...
mkdir "%WSL_HOME%\wpewebkit-browser-src" 2>nul
xcopy /E /Y /Q "%PLUGIN_SRC%src" "%WSL_HOME%\wpewebkit-browser-src\src\"
xcopy /Y /Q "%PLUGIN_SRC%xmake.lua" "%WSL_HOME%\wpewebkit-browser-src\"
xcopy /Y /Q "%PLUGIN_SRC%cross-build.sh" "%WSL_HOME%\wpewebkit-browser-src\"

REM 也复制整个插件目录
mkdir "%WSL_HOME%\wpewebkit-browser" 2>nul
xcopy /E /Y /Q "..\wpewebkit-browser\*" "%WSL_HOME%\wpewebkit-browser\"

echo   源码已复制到 WSL。

REM Step 3: 询问构建步骤
echo.
echo [3/4] 选择构建步骤:
echo    1 - 全部构建（工具链 + 依赖 + WebKit + 部署）
echo    2 - 仅安装工具链和依赖（准备环境）
echo    3 - 仅编译 WPE WebKit（已安装工具链和依赖）
echo    4 - 仅编译插件 .so（WebKit 已编译）
echo    5 - 部署到设备（已编译完成）
echo.
set /p CHOICE="请选择 [1-5]: "

if "%CHOICE%"=="1" set STEP=all
if "%CHOICE%"=="2" set STEP=deps
if "%CHOICE%"=="3" set STEP=webkit
if "%CHOICE%"=="4" set STEP=plugin
if "%CHOICE%"=="5" set STEP=deploy

if "%STEP%"=="" (
    echo 无效选择
    pause
    exit /b 1
)

REM Step 4: 在 WSL 中执行
echo [4/4] 在 WSL 中执行: cross-build.sh %STEP%
wsl -d %WSL_DISTRO% -e bash -c "cd ~/wpewebkit-browser-src && chmod +x cross-build.sh && ./cross-build.sh %STEP%"

echo.
echo ========================================
echo   编译完成！
echo ========================================
if "%STEP%"=="all" echo   产物位于 WSL: ~/wpewebkit-browser/
echo.

pause
