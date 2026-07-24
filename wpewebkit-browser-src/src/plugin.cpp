#include <QQmlEngine>
#include <QQmlContext>
#include <QObject>
#include <QVariant>
#include <QString>
#include <cstdio>

#include "WebViewItem.h"

// ============================================================
// BrowserController — 暴露给 QML 的全局辅助控制器
//
// 用于在 QML 中绑定全局属性（当前页面标题/URL/加载状态等），
// 简化 QML 层面的跨组件通信。
// WebViewItem 直接处理导航操作。
// ============================================================
class BrowserController : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString userAgent READ userAgent WRITE setUserAgent NOTIFY userAgentChanged)
    Q_PROPERTY(QString searchEngine READ searchEngine CONSTANT)

public:
    explicit BrowserController(QObject* parent = nullptr)
        : QObject(parent)
    {
        printf("[WPEBrowser] BrowserController created\n");
    }

    ~BrowserController() override
    {
        printf("[WPEBrowser] BrowserController destroyed\n");
    }

    QString userAgent() const { return m_userAgent; }
    void setUserAgent(const QString& ua)
    {
        if (ua != m_userAgent) {
            m_userAgent = ua;
            emit userAgentChanged();
        }
    }

    QString searchEngine() const { return "https://cn.bing.com/search?q=%1"; }

signals:
    void userAgentChanged();

private:
    QString m_userAgent;
};

// 全局指针（插件卸载时释放）
static BrowserController* g_controller = nullptr;

// ============================================================
// extern "C" 插件入口
//
// PenMods 宿主按以下顺序调用：
//   1. init_plugin()         — 初始化
//   2. attach_engine(engine) — 注册 QML 类型和上下文属性
//   3. destroy_plugin()      — 卸载清理
// ============================================================

extern "C" {

void init_plugin()
{
    printf("[WPEBrowser] init_plugin() called\n");
}

void attach_engine(QQmlEngine* engine)
{
    printf("[WPEBrowser] attach_engine() called\n");

    if (!engine) {
        printf("[WPEBrowser] ERROR: engine is null\n");
        return;
    }

    // 注册 WebViewItem 类型到 QML，QML 中可使用:
    //   import WPEWebKit 1.0
    //   WPEWebView { ... }
    qmlRegisterType<WebViewItem>("WPEWebKit", 1, 0, "WPEWebView");

    // 创建并暴露浏览器控制器到 QML 根上下文
    g_controller = new BrowserController();
    engine->rootContext()->setContextProperty("browserController", g_controller);

    printf("[WPEBrowser] QML types registered, controller exposed\n");
}

void destroy_plugin()
{
    printf("[WPEBrowser] destroy_plugin() called\n");

    if (g_controller) {
        delete g_controller;
        g_controller = nullptr;
    }
}

} // extern "C"

// Qt MOC 需要包含 .moc 文件（因为 BrowserController 声明在 .cpp 中）
#include "plugin.moc"
