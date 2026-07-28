#include "ShellController.h"

#include <QQmlContext>
#include <QQmlEngine>
#include <cstdio>

extern "C" {

void init_plugin() {
    std::printf("[shell_plugin] init_plugin\n");
}

void attach_engine(QQmlEngine* engine) {
    if (engine && engine->rootContext()) {
        auto* controller = ShellController::instance();
        QQmlEngine::setObjectOwnership(controller, QQmlEngine::CppOwnership);
        engine->rootContext()->setContextProperty("shellPluginController", controller);
    }
    std::printf("[shell_plugin] attach_engine\n");
}

void destroy_plugin() {
    ShellController::instance()->stopShell();
    std::printf("[shell_plugin] destroy_plugin\n");
}

}
