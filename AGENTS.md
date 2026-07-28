# AGENTS.md

面向 **有道词典笔**（YoudaoDictPen，ARM Cortex-A35x4 / Rockchip SoC，嵌入式 Linux）的 QML 程序，属于 **PenMods** 插件生态。https://github.com/Lyrecoul/PenMods

本目录本身就是插件集合根目录（设备上对应 `/userdisk/PenMods/plugins/`）。每个子目录是一个独立插件。下面文中 `plugins/<名>/` 即指本目录下的子目录。

## 目标设备（最关键约束）

- 屏幕固定 **320 × 170 px**：每个 QML 根 `Rectangle` 必须 `width: 320; height: 170`。不要用桌面尺寸。
- 运行时为 Qt 5.15.2，但插件统一 `import QtQuick 2.15`（兼容导入）。不要改成 `3.0`。
- UI 文案与代码注释用中文。
- 字号很小：`font.pixelSize` 7–12 为常态。

## 目录结构（本仓库）

- 纯 QML 插件示例（无 `main_so`）：`calculator/`、`2048_plugin/`、`dino/`、`minesweeper_plugin/`、`weather/`、`browser/`、`60s/`、`com.text.editor/`、`tts_demo/`、`shell_demo/`。
- 原生插件示例（带 `main_so` 的 `.so`）：`systemmonitor/`、`shell_plugin/`、`words_plugin/`、`clock_plugin/`、`bili_plugin/`、`novel-reader/`。
- 原生插件**源码目录**（独立，含 `xmake.lua`，不部署到设备）：`plugin_src/`（clock）、`shell_plugin源码/`、`bili_plugin-src/`。改 `.so` 行为时改这里，然后交叉编译后把产物 `.so` 拷回对应插件目录。
- 文档：`PLUGIN_HOOK_DEV_GUIDE.md`（原生 Hook API：`init_plugin_with_hook_api`、`querySymbol`、`hookFunction`，改系统行为前必读）；`60s/README.md`、`novel-reader/README.md` 有插件内机制说明。
- `systemmonitor/` 是 QML + 原生 `.so` 范例，示范如何通过 shell 插件读 `/proc`、`/sys`（见其 `main.qml` 与 `monitor.sh`）。

## PenMods 插件结构

纯 QML 插件就是一个文件夹，包含：

- `metadata.json` —— 必需清单（schema 见下）
- `main_qml` 指定的入口 QML 文件（通常 `main.qml`，也有 `2048.qml`、`calculator.qml` 等）
- `icon.png`（或 `icon` 字段指向的其他图片）

`metadata.json` schema（参考 `calculator/metadata.json`）：

```json
{
  "id": "com.<组>.<名>",
  "name": "显示名",
  "version": "1.0.0",
  "author": "...",
  "description": "...",
  "icon": "file://userdisk/PenMods/plugins/<名>/icon.png",
  "main_qml": "main.qml"
}
```

要点：

- `id` 为反序域名，**可含中文**（如 `com.markdown.计算器`、`com.game.2048`）。
- `icon` 两种写法：设备上插件图标 `file://userdisk/PenMods/plugins/<名>/icon.png`；或宿主内置资源 `qrc:/images/home/home-plugin.png`。
- 插件在设备上安装到 `/userdisk/PenMods/plugins/<名>/`。
- 纯 QML 插件**无构建步骤**：PenMods 宿主直接加载 QML。不要为纯 QML 插件加 CMake/qmake/xmake。
- `main_qml` 可指向子目录（如 `qml/main.qml`，见 `shell_plugin/`、`words_plugin/`、`bili_plugin/`）。

## QML 约定

- 根 `Rectangle` 声明 `signal backButtonClicked()`：宿主连接此信号以返回启动器。从返回按钮的 `MouseArea.onClicked` 触发它。
- 持久化用 `import QtQuick.LocalStorage 2.15`：
  ```qml
  var db = LocalStorage.openDatabaseSync("MyDB", "1.0", "desc", 100000)
  db.transaction(function(tx) {
      tx.executeSql('CREATE TABLE IF NOT EXISTS kv (k TEXT PRIMARY KEY, v TEXT)')
      tx.executeSql('INSERT OR REPLACE INTO kv (k,v) VALUES(?,?)', [key, val])
  })
  ```
  外层包 `try/catch` —— 存储可能不可用，约定是**静默回退到内存**（见 `dino/main.qml` 注释）。
- 联网用 `XMLHttpRequest`（Qt 内置 XHR 在 QML 可用）。务必加 `_t=<时间戳>` 缓存规避参数，否则 Qt/XHR 会返回过期内容（见 `60s/README.md`）。
- 自定义绘制用 `Canvas { onPaint: { var ctx = getContext("2d"); ... } }`，需重绘时调 `requestPaint()`。
- 游戏循环 / 轮询用 `Timer { interval: 16; repeat: true; running: ... }`（16ms ≈ 60fps）。

## Shell 插件（仅当需要系统/shell 访问时）

宿主注入 `shellPluginController` 对象（常用 `property var sh: shellPluginController` 别名）。API：

- `sh.startShell()` / `sh.stopShell()` —— 启停后台 shell
- `sh.sendCommand(str)` —— 发送命令（长驻 `while true; do ...; done` 循环可用）
- `sh.outputText` —— 累积 stdout（在轮询 `Timer` 中读取；超过约 60000 字符时 `clearOutput()`）
- 在 `Component.onDestruction` 里发 `"\x03"`（Ctrl-C）停止循环。

系统信息设备路径：`/proc/stat`、`/proc/meminfo`、`/sys/class/power_supply/battery/*`、`/sys/block/mmcblk1/device/*`、`/sys/class/thermal/thermal_zone*/temp`。完整范例见 `../systemmonitor/main.qml` 与 `monitor.sh`。

## 原生插件（.so，仅当 QML 不够时）

若必须用 C++，可在 `metadata.json` 加 `"main_so": "libxxx.so"`（见 `systemmonitor/`、`shell_plugin/`、`bili_plugin/`）。宿主加载 `.so` 时按序调用以下 `extern "C"` 入口（参考 `shell_plugin源码/src/plugin.cpp`、`bili_plugin-src/src/BiliController.cpp`）：

- `init_plugin()` —— 早期基础初始化（可选）。
- `attach_engine(QQmlEngine* engine)` —— 引擎附加时调用：`engine->rootContext()->setContextProperty("xxxController", obj)` 暴露给 QML，或 `engine->addImageProvider("name", provider)` 注册图片提供者（见 bili）。
- `destroy_plugin()` —— 卸载清理（停进程、删对象等，可选）。
- Hook 入口 `init_plugin_with_hook_api(PluginHookAPI*)` —— 仅拦截系统函数时用，API 详见 `PLUGIN_HOOK_DEV_GUIDE.md`。

源码目录用 **xmake** 构建（`xmake.lua`）：`set_kind('shared')` + `add_rules('qt.shared')`，`add_frameworks('QtCore','QtQuick','QtQml', ...)`。需设备 ARM 交叉编译工具链；`bili_plugin-src/go_server/build.sh` 是 Go 侧服务的 `GOOS=linux GOARCH=arm64` 编译示例。产物 `.so` 拷回插件目录即可，非必要不引入 C++。

## 桌面开发调试（可选）

要在桌面单独跑某插件的 QML 测试，用 Qt Creator 的 CMake 工程（`qt_add_qml_module` + `main.cpp` 里 `engine.loadFromModule(...)`）。这只是**测试骨架**，不部署到设备，也无 `metadata.json`/`icon`。注意：本目录无现成桌面骨架，需自行新建；宿主注入对象（`shellPluginController` 等）在桌面缺失，测试时需 mock 或用 `typeof` 判空。
