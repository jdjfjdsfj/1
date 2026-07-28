#include <QDebug>
#include <QtQml>
#include <iostream>
#include "ClockController.h"

// 必须使用 extern "C"，否则 C++ 的 Name Mangling 会导致 PluginManager 找不到函数
extern "C" {
void init_plugin() {
    qDebug() << "Clock Plugin: Initializing...";

    // 示例：在插件加载时注册一个 QML 类型
    // 这样 main.qml 就可以使用 import MyPlugins.Clock 1.0
    qmlRegisterType<ClockController>("MyPlugins.Clock", 1, 0, "ClockController");

    std::cout << "Clock Plugin: Registered successfully!" << std::endl;
}
}
