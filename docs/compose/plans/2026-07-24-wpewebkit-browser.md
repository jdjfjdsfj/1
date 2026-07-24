# WPE WebKit 浏览器插件 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use compose:subagent (recommended) or compose:execute to implement this plan task-by-task.

**Goal:** 创建基于 WPE WebKit 的浏览器插件，UI 与功能完全兼容现有文本浏览器。

**Architecture:** 原生 .so 提供 WebViewItem（QQuickItem，WPE 渲染）和 BrowserController（context property）。QML 层复用现有 UI。

**Tech Stack:** C++17, Qt 5.15, WPE WebKit 2.x + wpebackend-fdo, xmake

## Global Constraints

- 屏幕 320x170，根 Rectangle `width: 320; height: 170`
- `import QtQuick 2.15`（兼容 Qt 5.15.2）
- UI 文案用中文
- 部署到 `/userdisk/PenMods/plugins/wpewebkit-browser/`
- 源码独立于插件目录，xmake 构建
- 必须导出 `backButtonClicked()` 信号
- metadata.json 含 main_so 字段

---

### Task 1: 创建目录结构和 metadata.json

**Files:**
- Create: `wpewebkit-browser/metadata.json`
- Create: `wpewebkit-browser/TitleBar.qml` (copy from `browser/TitleBar.qml`)
- Create: `wpewebkit-browser/history.qml` (copy from `browser/history.qml`)
- Create: `wpewebkit-browser/settings.qml` (adapted)

**Interfaces:**
- Produces: metadata.json with id `com.wpe.browser`, main_so `libwpewebkit_browser.so`

- [ ] **Step 1: 创建 metadata.json**

```json
{
    "id": "com.wpe.浏览器",
    "name": "WPE浏览器",
    "version": "1.0.0",
    "author": "MiMoCode",
    "description": "基于WPE WebKit的浏览器插件，完整支持网页渲染",
    "icon": "qrc:/images/home/home-plugin.png",
    "main_qml": "main.qml",
    "main_so": "libwpewebkit_browser.so"
}
```

- [ ] **Step 2: 复制 TitleBar.qml（完全不变）**

复制 `browser/TitleBar.qml` 到 `wpewebkit-browser/TitleBar.qml`

- [ ] **Step 3: 复制 history.qml（完全不变）**

复制 `browser/history.qml` 到 `wpewebkit-browser/history.qml`

- [ ] **Step 4: 创建 settings.qml（适配 WPE）**

适配项：移除"查看原始网页内容"(WPE 不需要)，保留缩放/搜索结果/换行设置。

---

### Task 2: 实现 C++ WebViewItem（QQuickItem + WPE WebKit 渲染）

**Files:**
- Create: `wpewebkit-browser-src/src/WebViewItem.h`
- Create: `wpewebkit-browser-src/src/WebViewItem.cpp`

**Interfaces:**
- Produces: `WebViewItem` QQuickItem 类，注册为 `WPEWebKit.WPEWebView 1.0`
- Properties: title(string), url(string), loading(bool), loadProgress(int), zoomFactor(real)
- Methods: loadUrl(url), goBack(), goForward(), reload(), stop()

- [ ] **Step 1: 编写 WebViewItem.h**

```cpp
#ifndef WEBVIEWITEM_H
#define WEBVIEWITEM_H

#include <QQuickItem>
#include <QSGSimpleTextureNode>
#include <QSGTexture>
#include <QQuickWindow>

// WPE WebKit headers
#include <wpe/wpe.h>
#include <wpe/webkit.h>

class WebViewItem : public QQuickItem {
    Q_OBJECT
    Q_PROPERTY(QString title READ title NOTIFY titleChanged)
    Q_PROPERTY(QString url READ url NOTIFY urlChanged)
    Q_PROPERTY(bool loading READ isLoading NOTIFY loadingChanged)
    Q_PROPERTY(int loadProgress READ loadProgress NOTIFY loadProgressChanged)
    Q_PROPERTY(qreal zoomFactor READ zoomFactor WRITE setZoomFactor NOTIFY zoomFactorChanged)

public:
    explicit WebViewItem(QQuickItem* parent = nullptr);
    ~WebViewItem() override;

    QString title() const { return m_title; }
    QString url() const { return m_url; }
    bool isLoading() const { return m_loading; }
    int loadProgress() const { return m_loadProgress; }
    qreal zoomFactor() const { return m_zoomFactor; }
    void setZoomFactor(qreal factor);

    Q_INVOKABLE void loadUrl(const QString& u);
    Q_INVOKABLE void goBack();
    Q_INVOKABLE void goForward();
    Q_INVOKABLE void reload();
    Q_INVOKABLE void stop();

signals:
    void titleChanged();
    void urlChanged();
    void loadingChanged();
    void loadProgressChanged();
    void zoomFactorChanged();

protected:
    QSGNode* updatePaintNode(QSGNode* old, UpdatePaintNodeData*) override;
    void geometryChanged(const QRectF& newGeom, const QRectF& oldGeom) override;
    void mousePressEvent(QMouseEvent* event) override;
    void mouseReleaseEvent(QMouseEvent* event) override;
    void mouseMoveEvent(QMouseEvent* event) override;
    void wheelEvent(QWheelEvent* event) override;
    void keyPressEvent(QKeyEvent* event) override;
    void keyReleaseEvent(QKeyEvent* event) override;

private:
    struct wpe_view_backend* m_wpeBackend = nullptr;
    WebKitWebView* m_webView = nullptr;

    QString m_title;
    QString m_url;
    bool m_loading = false;
    int m_loadProgress = 0;
    qreal m_zoomFactor = 1.0;

    QSGTexture* m_texture = nullptr;
    bool m_frameDirty = false;
    int m_viewWidth = 320;
    int m_viewHeight = 150;

    void initWPE();
    void cleanupWPE();
    void resizeView();
    void processFrame();

    // Static callbacks
    static void onExportEGLImage(void* data, void* image);
    static gboolean onFrameDisplayed(gpointer data);
    static void onLoadChanged(WebKitWebView* view, WebKitLoadEvent event, gpointer data);
    static void onTitleChanged(GObject* obj, GParamSpec* pspec, gpointer data);
    static void onProgressChanged(GObject* obj, GParamSpec* pspec, gpointer data);
    static gboolean onDecidePolicy(WebKitWebView* view, WebKitPolicyDecision* decision,
                                    WebKitPolicyDecisionType type, gpointer data);
};

#endif // WEBVIEWITEM_H
```

- [ ] **Step 2: 编写 WebViewItem.cpp 构造函数与 WPE 初始化**

```cpp
#include "WebViewItem.h"
#include <QOpenGLContext>
#include <QOpenGLFunctions>
#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <WPEBackend-fdo-1.0.h>
#include <cstdio>
#include <GLES2/gl2.h>

// EGL image for the current frame
static void* s_currentImage = nullptr;
static QSGTexture* s_sharedTexture = nullptr;

WebViewItem::WebViewItem(QQuickItem* parent)
    : QQuickItem(parent)
{
    setFlag(QQuickItem::ItemHasContents, true);
    setAcceptedMouseButtons(Qt::AllButtons);
    setAcceptHoverEvents(true);
    setFocus(true);
    initWPE();
}

WebViewItem::~WebViewItem()
{
    cleanupWPE();
}

void WebViewItem::initWPE()
{
    // 创建 wpebackend-fdo 后端（用于渲染到 EGL image）
    // 导出回调：WPE 每渲染一帧都会调用
    static struct wpe_view_backend_exportable_fdo_client client = {
        // export_egl_image - WPE 导出渲染好的 EGL image
        [](void* data, EGLImageKHR image) {
            s_currentImage = (void*)image;
            auto* self = static_cast<WebViewItem*>(data);
            self->m_frameDirty = true;
            self->update();
        },
        // export_fdo_egl_image - 另一种导出方式
        nullptr,
        // padding 预留
        nullptr, nullptr, nullptr, nullptr
    };

    m_wpeBackend = wpe_view_backend_exportable_fdo_create(&client, this, 320, 150);

    // 使用 WPE WebKit API 创建 WebView
    WebKitWebViewBackend* wkBackend = webkit_web_view_backend_new(
        m_wpeBackend,
        [](gpointer data) {
            auto* self = static_cast<WebViewItem*>(data);
            delete self;
        },
        this
    );

    m_webView = WEBKIT_WEB_VIEW(g_object_new(WEBKIT_TYPE_WEB_VIEW,
        "backend", wkBackend,
        "web-context", webkit_web_context_get_default(),
        nullptr));

    // 连接信号
    g_signal_connect(m_webView, "load-changed", G_CALLBACK(onLoadChanged), this);
    g_signal_connect(m_webView, "notify::title", G_CALLBACK(onTitleChanged), this);
    g_signal_connect(m_webView, "notify::estimated-load-progress",
                     G_CALLBACK(onProgressChanged), this);
    g_signal_connect(m_webView, "decide-policy",
                     G_CALLBACK(onDecidePolicy), this);

    // 设置默认缩放和背景
    webkit_web_view_set_zoom_level(m_webView, 0.0);
    WebKitColor bg = { 255, 255, 255, 255 };
    webkit_web_view_set_background_color(m_webView, &bg);
}

void WebViewItem::cleanupWPE()
{
    s_sharedTexture = nullptr;
    if (m_webView) {
        g_object_unref(m_webView);
        m_webView = nullptr;
    }
}

// ---- WPE Callbacks ----

void WebViewItem::onLoadChanged(WebKitWebView*, WebKitLoadEvent event, gpointer data)
{
    auto* self = static_cast<WebViewItem*>(data);
    QMetaObject::invokeMethod(self, [self, event]() {
        switch (event) {
        case WEBKIT_LOAD_STARTED:
            self->m_loading = true;
            self->m_title.clear();
            emit self->loadingChanged();
            emit self->titleChanged();
            break;
        case WEBKIT_LOAD_FINISHED:
            self->m_loading = false;
            self->m_loadProgress = 100;
            self->m_url = QString::fromUtf8(
                webkit_web_view_get_uri(self->m_webView) ?: "");
            emit self->loadingChanged();
            emit self->urlChanged();
            emit self->loadProgressChanged();
            break;
        default:
            break;
        }
    }, Qt::QueuedConnection);
}

void WebViewItem::onTitleChanged(GObject* obj, GParamSpec*, gpointer data)
{
    auto* self = static_cast<WebViewItem*>(data);
    const char* title = webkit_web_view_get_title(WEBKIT_WEB_VIEW(obj));
    QMetaObject::invokeMethod(self, [self, t = QString::fromUtf8(title ?: "")]() {
        self->m_title = t;
        emit self->titleChanged();
    }, Qt::QueuedConnection);
}

void WebViewItem::onProgressChanged(GObject* obj, GParamSpec*, gpointer data)
{
    auto* self = static_cast<WebViewItem*>(data);
    double progress = webkit_web_view_get_estimated_load_progress(WEBKIT_WEB_VIEW(obj));
    QMetaObject::invokeMethod(self, [self, p = int(progress * 100)]() {
        self->m_loadProgress = p;
        emit self->loadProgressChanged();
    }, Qt::QueuedConnection);
}

static gboolean onDecidePolicy(WebKitWebView*, WebKitPolicyDecision* decision,
                                WebKitPolicyDecisionType type, gpointer data)
{
    if (type == WEBKIT_POLICY_DECISION_TYPE_NAVIGATION_ACTION) {
        auto* nav = WEBKIT_NAVIGATION_POLICY_DECISION(decision);
        auto* action = webkit_navigation_policy_decision_get_navigation_action(nav);
        auto* request = webkit_navigation_action_get_request(action);
        const char* uri = webkit_uri_request_get_uri(request);

        auto* self = static_cast<WebViewItem*>(data);
        QMetaObject::invokeMethod(self, [self, u = QString::fromUtf8(uri ?: "")]() {
            self->m_url = u;
            emit self->urlChanged();
        }, Qt::QueuedConnection);
    }
    return FALSE; // 允许导航
}
```

- [ ] **Step 3: 编写导航与缩放方法**

```cpp
void WebViewItem::loadUrl(const QString& u)
{
    if (m_webView && !u.isEmpty()) {
        webkit_web_view_load_uri(m_webView, u.toUtf8().constData());
    }
}

void WebViewItem::goBack()
{
    if (m_webView && webkit_web_view_can_go_back(m_webView))
        webkit_web_view_go_back(m_webView);
}

void WebViewItem::goForward()
{
    if (m_webView && webkit_web_view_can_go_forward(m_webView))
        webkit_web_view_go_forward(m_webView);
}

void WebViewItem::reload()
{
    if (m_webView)
        webkit_web_view_reload(m_webView);
}

void WebViewItem::stop()
{
    if (m_webView)
        webkit_web_view_stop_loading(m_webView);
}

void WebViewItem::setZoomFactor(qreal factor)
{
    if (factor != m_zoomFactor && factor >= 0.5 && factor <= 3.0) {
        m_zoomFactor = factor;
        double level = log(factor) / log(1.2); // WebKit zoom level
        webkit_web_view_set_zoom_level(m_webView, level);
        emit zoomFactorChanged();
    }
}
```

- [ ] **Step 4: 编写 updatePaintNode 渲染管线**

```cpp
QSGNode* WebViewItem::updatePaintNode(QSGNode* old, UpdatePaintNodeData*)
{
    auto* node = static_cast<QSGSimpleTextureNode*>(old);
    auto* win = window();

    if (!win || !s_currentImage) {
        if (!node) {
            node = new QSGSimpleTextureNode();
            QSGTexture* placeholder = win ? win->createTextureFromImage(
                QImage(1, 1, QImage::Format_ARGB32)) : nullptr;
            if (placeholder) {
                node->setTexture(placeholder);
                node->setOwnsTexture(true);
            }
        }
        node->setRect(boundingRect());
        return node;
    }

    if (!node || m_frameDirty) {
        if (!node) {
            node = new QSGSimpleTextureNode();
        }

        // 从 EGL image 创建 OpenGL 纹理
        // wpebackend-fdo 导出的 EGLImage 需要通过 EGL 扩展绑定到 GL 纹理
        if (win->openglContext()) {
            auto* gl = win->openglContext()->functions();
            EGLImageKHR eglImage = (EGLImageKHR)s_currentImage;

            // 创建 GL 纹理并绑定 EGLImage
            GLuint texId = 0;
            gl->glGenTextures(1, &texId);
            gl->glBindTexture(GL_TEXTURE_2D, texId);

            // 使用 EGL image target 扩展
            using glEGLImageTargetTexture2DOES_t = void (*)(GLenum, GLeglImageOES);
            auto glEGLImageTargetTexture2DOES =
                (glEGLImageTargetTexture2DOES_t)eglGetProcAddress("glEGLImageTargetTexture2DOES");
            if (glEGLImageTargetTexture2DOES) {
                glEGLImageTargetTexture2DOES(GL_TEXTURE_2D, (GLeglImageOES)eglImage);
            }

            gl->glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
            gl->glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

            // 用 native 纹理 ID 创建 QSGTexture
            QSGTexture* tex = win->createTextureFromNativeObject(
                QQuickWindow::NativeObjectTexture, &texId, 0,
                QSize(m_viewWidth, m_viewHeight),
                QQuickWindow::TextureHasAlphaChannel);

            if (node->texture())
                delete node->texture();
            node->setTexture(tex);
            node->setOwnsTexture(true);
        }

        m_frameDirty = false;
    }

    node->setRect(boundingRect());
    return node;
}
```

- [ ] **Step 5: 编写输入事件转发和尺寸管理**

```cpp
void WebViewItem::geometryChanged(const QRectF& newGeom, const QRectF& oldGeom)
{
    QQuickItem::geometryChanged(newGeom, oldGeom);
    int w = (int)newGeom.width();
    int h = (int)newGeom.height();
    if (w > 0 && h > 0 && (w != m_viewWidth || h != m_viewHeight)) {
        m_viewWidth = w;
        m_viewHeight = h;
        resizeView();
    }
}

void WebViewItem::resizeView()
{
    if (m_wpeBackend) {
        wpe_view_backend_dispatch_set_size(m_wpeBackend, m_viewWidth, m_viewHeight);
    }
}

void WebViewItem::mousePressEvent(QMouseEvent* event)
{
    QQuickItem::mousePressEvent(event);
    // 转发给 WPE: map to content coordinates and send touch/mouse event
    // wpe_input_* 或 wpe_view_backend_dispatch_* API
}

void WebViewItem::mouseReleaseEvent(QMouseEvent* event)
{
    QQuickItem::mouseReleaseEvent(event);
}

void WebViewItem::mouseMoveEvent(QMouseEvent* event)
{
    QQuickItem::mouseMoveEvent(event);
}

void WebViewItem::wheelEvent(QWheelEvent* event)
{
    QQuickItem::wheelEvent(event);
}

void WebViewItem::keyPressEvent(QKeyEvent* event)
{
    QQuickItem::keyPressEvent(event);
}

void WebViewItem::keyReleaseEvent(QKeyEvent* event)
{
    QQuickItem::keyReleaseEvent(event);
}
```

---

### Task 3: 编写 C++ 插件入口点

**File:** `wpewebkit-browser-src/src/plugin.cpp`

- [ ] **Step 1: 编写 plugin.cpp**

```cpp
#include <QQmlEngine>
#include <QQmlContext>
#include <QObject>
#include <QVariant>
#include "WebViewItem.h"

// ---- BrowserController: 暴露给 QML 的辅助控制器 ----
class BrowserController : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString title READ title NOTIFY titleChanged)
    Q_PROPERTY(QString url READ url NOTIFY urlChanged)
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)

public:
    explicit BrowserController(QObject* parent = nullptr) : QObject(parent) {}

    QString title() const { return m_title; }
    QString url() const { return m_url; }
    bool loading() const { return m_loading; }

    void setTitle(const QString& t) { if (t != m_title) { m_title = t; emit titleChanged(); } }
    void setUrl(const QString& u) { if (u != m_url) { m_url = u; emit urlChanged(); } }
    void setLoading(bool l) { if (l != m_loading) { m_loading = l; emit loadingChanged(); } }

signals:
    void titleChanged();
    void urlChanged();
    void loadingChanged();

private:
    QString m_title;
    QString m_url;
    bool m_loading = false;
};

static BrowserController* g_controller = nullptr;

extern "C" {

void init_plugin()
{
    printf("[WPEBrowser] Plugin initializing...\n");
}

void attach_engine(QQmlEngine* engine)
{
    printf("[WPEBrowser] Attaching to QML engine...\n");

    // 注册 WebViewItem 类型到 QML
    qmlRegisterType<WebViewItem>("WPEWebKit", 1, 0, "WPEWebView");

    // 创建并暴露浏览器控制器
    g_controller = new BrowserController();
    engine->rootContext()->setContextProperty("browserController", g_controller);
}

void destroy_plugin()
{
    printf("[WPEBrowser] Plugin destroying...\n");
    if (g_controller) {
        delete g_controller;
        g_controller = nullptr;
    }
}

}
#include "plugin.moc"
```

---

### Task 4: 编写 xmake.lua 构建配置

**File:** `wpewebkit-browser-src/xmake.lua`

- [ ] **Step 1: 编写 xmake.lua**

```lua
set_project("wpewebkit-browser")
set_version("1.0.0")

add_rules("mode.debug", "mode.release")
add_rules("qt.shared")

target("wpewebkit_browser")
    set_kind("shared")
    set_filename("libwpewebkit_browser.so")

    -- Qt 模块
    add_frameworks("Qt5Core", "Qt5Quick", "Qt5Gui", "Qt5Qml")

    -- WPE WebKit 依赖
    add_options("wpewebkit")
    if has_config("wpewebkit") then
        add_cxflags(get_config("wpewebkit_cflags"))
        add_ldflags(get_config("wpewebkit_ldflags"))
        add_links(get_config("wpewebkit_libs"))
    else
        -- 手动指定（按设备实际路径调整）
        add_links("wpe-1.0", "wpebackend-fdo-1.0", "wpewebkit-2.0")
    end

    -- EGL/GLES
    add_links("EGL", "GLESv2")

    -- 源文件
    add_files("src/**.cpp")
    add_headerfiles("src/**.h")

    -- Qt MOC 处理
    add_files("src/**.h", {rules = "qt.moc"})

    -- 包含路径
    add_includedirs("src")
```

---

### Task 5: 编写 main.qml（核心 UI）

**File:** `wpewebkit-browser/main.qml`

**Architecture:** 根布局与现有浏览器完全相同（TitleBar + URL栏 + 菜单 + 历史/设置 Loader + 书签），仅将中间的 `Flickable > Text` 替换为 `WPEWebView`。

- [ ] **Step 1: 编写完整 main.qml**

参考 `browser/main.qml` 的结构：
- 保留 TitleBar、URL 栏、菜单、加载提示、历史/设置 Loader、键盘辅助、书签列表
- 内容区域从 `Flickable > Text` 换为 `WPEWebView { id: webView; anchors.fill: parent }`
- 导航按钮调用 `webView.loadUrl/ goBack/ goForward/ reload/ stop`
- 绑定 `webView.title` -> TitleBar.title, `webView.url` -> 地址栏
- 菜单简化：移除"查看原始网页内容"，缩放改用 `webView.zoomFactor`

```qml
import QtQuick 2.15
import QtQuick.LocalStorage 2.0
import WPEWebKit 1.0
import "qrc:/qml/commons"

Rectangle {
    id: root
    width: 320
    height: 170
    color: "#F5F5F5"

    signal backButtonClicked()

    // ---- URL格式化与搜索（同原浏览器） ----
    property string currentInput: ""
    property var presets: [
        { name: "一言", url: "https://v1.hitokoto.cn/?c=a&encode=text" },
        { name: "必应", url: "https://cn.bing.com" },
        { name: "哔哩哔哩", url: "https://www.bilibili.com" }
    ]
    property bool menuVisible: false
    property bool keyboardPending: false
    property var db: null

    function formatUrl(input) {
        var t = input.trim()
        if (t === "") return ""
        if (/^[a-zA-Z][a-zA-Z0-9+\\-.]*:\\/\\//.test(t)) return t
        if (/^\\/\\//.test(t)) return "https:" + t
        if (t.indexOf('.') > 0 && t.indexOf(' ') === -1) return "https://" + t
        return "https://cn.bing.com/search?q=" + encodeURIComponent(t)
    }

    // ---- 持久化 ----
    function initDatabase() {
        try {
            db = LocalStorage.openDatabaseSync("WPEBrowser", "1.0", "wpe浏览器状态", 100000)
            db.transaction(function(tx) {
                tx.executeSql("CREATE TABLE IF NOT EXISTS state(key TEXT PRIMARY KEY, value TEXT)")
            })
            loadState()
        } catch(e) { db = null }
    }

    function saveState() {
        if (!db) return
        db.transaction(function(tx) {
            tx.executeSql("INSERT OR REPLACE INTO state(key,value) VALUES('presets',?)",
                          [JSON.stringify(presets)])
        })
    }

    function loadState() {
        if (!db) return
        db.readTransaction(function(tx) {
            var rs = tx.executeSql("SELECT value FROM state WHERE key='presets'")
            if (rs.rows.length > 0) presets = JSON.parse(rs.rows.item(0).value)
        })
    }

    // ---- 导航 ----
    function goHome() { webView.stop(); webView.loadUrl("about:blank") }
    function requestExit() { saveState(); backButtonClicked() }

    // ---- 键盘 ----
    function _createKeyboard(initialText, callback) {
        if (qmlGlobal.inputPageShowing || keyboardPending) return
        keyboardPending = true
        var comp = qmlCreateComponent("YInputPage")
        if (comp.status === Component.Ready) {
            var incubator = comp.incubateObject(pagePopHelper.containerItem)
            if (incubator.status !== Component.Ready) {
                incubator.onStatusChanged = function(s) {
                    if (s === Component.Ready) _setupKeyboard(incubator.object, initialText, callback)
                }
            } else { _setupKeyboard(incubator.object, initialText, callback) }
        } else { keyboardPending = false }
    }

    function _setupKeyboard(kp, text, cb) {
        kp.backButtonClicked.connect(function() { qmlGlobal.inputPageShowing = false; kp.todoDestroy(); keyboardPending = false })
        kp.inputFinished.connect(function(c) { qmlGlobal.inputPageShowing = false; kp.todoDestroy(); if (c && cb) cb(c); keyboardPending = false })
        kp.enterText(text); kp.show(); qmlGlobal.inputPageShowing = true
    }

    function handleUrlSubmit(text) {
        var f = formatUrl(text)
        if (f) { currentInput = ""; webView.loadUrl(f) }
    }

    // ---- 书签 ----
    function editPreset(index) {
        if (index < 0 || index >= presets.length) return
        var p = presets[index]
        _createKeyboard(p.name + "," + p.url, function(ns) {
            if (!ns) return
            var s = ns.replace(/[\\r\\n]/g, "").trim()
            if (s === "") { presets.splice(index, 1); presets = presets; saveState(); return }
            var ci = s.indexOf(",")
            var nm, ur
            if (ci === -1) { nm = s; ur = s }
            else { nm = s.substring(0, ci).trim(); ur = s.substring(ci+1).trim() }
            if (nm === "" || ur === "") { presets.splice(index, 1) }
            else { presets[index].name = nm; presets[index].url = ur }
            presets = presets; saveState()
        })
    }

    function addPreset() {
        if (presets.length >= 20) return
        presets.push({ name: "书签", url: "https://" }); presets = presets; saveState()
    }

    // ---- 历史/设置 ----
    function showHistoryPage() { menuVisible = false; historyLoader.show() }
    function closeHistory() { historyLoader.hide() }
    function handleHistoryUrlClicked(url) { webView.loadUrl(url); closeHistory() }
    function showSettingsPage() { menuVisible = false; settingsLoader.show() }
    function closeSettings() { settingsLoader.hide() }

    // ---- 缩放 ----
    function zoomIn() { webView.zoomFactor = Math.min(2.5, webView.zoomFactor + 0.25) }
    function zoomOut() { webView.zoomFactor = Math.max(0.5, webView.zoomFactor - 0.25) }

    // ========== UI 布局 ==========

    TitleBar {
        id: titleBar
        width: parent.width; height: 20
        title: webView.title || "主页"
    }

    Column {
        anchors.top: titleBar.bottom
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom

        // ---- 内容区域：WPE WebView ----
        Item {
            width: parent.width; height: parent.height - 30; clip: true

            WPEWebView {
                id: webView
                anchors.fill: parent
            }

            // 主页书签列表 (URL为空时显示)
            Item {
                id: homePresets
                anchors.fill: parent
                visible: !webView.url
                z: 1

                ListView {
                    anchors.fill: parent
                    model: presets
                    delegate: Rectangle {
                        width: parent.width; height: 30
                        color: ma.pressed ? "#E0E0E0" : "transparent"
                        Row {
                            anchors.fill: parent; anchors.leftMargin: 5; anchors.rightMargin: 5
                            Text {
                                anchors.centerIn: parent; width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                text: modelData.url; font.pixelSize: 16; color: "#000000"
                                visible: modelData.name === modelData.url
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter; width: 90
                                text: modelData.name.substring(0,5); font.pixelSize: 16; color: "#000000"
                                visible: modelData.name !== modelData.url
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter; anchors.right: parent.right
                                width: parent.width - 90
                                text: modelData.url; font.pixelSize: 16; color: "#000000"
                                elide: Text.ElideRight; horizontalAlignment: Text.AlignRight
                                visible: modelData.name !== modelData.url
                            }
                        }
                        MouseArea {
                            id: ma; anchors.fill: parent
                            onClicked: webView.loadUrl(modelData.url)
                            onPressAndHold: editPreset(index)
                        }
                    }
                    footer: Item {
                        width: parent.width; height: presets.length < 20 ? 30 : 0
                        visible: presets.length < 20
                        Rectangle {
                            anchors.fill: parent; color: pa.pressed ? "#E0E0E0" : "transparent"
                            Text { anchors.centerIn: parent; text: "添加书签"; font.pixelSize: 16; color: "#000000" }
                            MouseArea { id: pa; anchors.fill: parent; onClicked: addPreset() }
                        }
                    }
                    boundsBehavior: Flickable.StopAtBounds; clip: true
                }
            }
        }

        // ---- 底部栏 ----
        Rectangle {
            width: parent.width; height: 30; color: "#EEEEEE"; border.color: "#CCCCCC"; border.width: 0.5
            Row {
                anchors.fill: parent; anchors.leftMargin: 4; anchors.rightMargin: 4; spacing: 4
                Rectangle {
                    width: parent.width - 53; height: 26; anchors.verticalCenter: parent.verticalCenter; radius: 3
                    color: "#FFFFFF"; border.color: "#CCCCCC"; border.width: 0.5
                    Text {
                        anchors.fill: parent; anchors.leftMargin: 6; anchors.rightMargin: 6
                        verticalAlignment: Text.AlignVCenter
                        text: webView.url || "输入网址或搜索词"
                        font.pixelSize: 12; color: webView.url ? "#000000" : "#AAAAAA"
                        elide: Text.ElideRight
                    }
                    MouseArea { anchors.fill: parent; onClicked: _createKeyboard(webView.url, function(c) { handleUrlSubmit(c) }) }
                }
                Rectangle {
                    width: 45; height: 26; anchors.verticalCenter: parent.verticalCenter; radius: 3
                    color: mba.pressed ? "#D0D0D0" : "#E0E0E0"; border.color: "#B0B0B0"; border.width: 0.5
                    Text { anchors.centerIn: parent; text: "菜单"; font.pixelSize: 13; color: "#000000" }
                    MouseArea { id: mba; anchors.fill: parent; onClicked: menuVisible = !menuVisible }
                }
            }
        }
    }

    // ---- 加载提示 ----
    Rectangle {
        visible: webView.loading
        x: (root.width - 135) / 2; y: 20; z: 10; width: 135; height: 30; radius: 6
        color: "#FFFFFF"; border.color: "#DDDDDD"; border.width: 1
        Text {
            anchors.centerIn: parent
            text: "加载中… " + webView.loadProgress + "%"
            font.pixelSize: 13; color: "#000000"
        }
        MouseArea { anchors.fill: parent; onClicked: webView.stop() }
    }

    // ---- 菜单 ----
    Rectangle {
        visible: menuVisible
        x: parent.width - 116 - 6; y: parent.height - 30 - 96 - 2
        width: 116; height: 96; radius: 4
        color: "#FFFFFF"; border.color: "#AAAAAA"; border.width: 1; z: 98
        Grid {
            anchors.fill: parent; anchors.margins: 3; columns: 2; rows: 4; spacing: 0
            MenuItem { text: "返回"; onTriggered: { webView.goBack(); menuVisible = false } }
            MenuItem { text: "前进"; onTriggered: { webView.goForward(); menuVisible = false } }
            MenuItem { text: "刷新"; onTriggered: { webView.reload(); menuVisible = false } }
            MenuItem { text: "主页"; onTriggered: { goHome(); menuVisible = false } }
            MenuItem { text: "放大"; onTriggered: { zoomIn(); menuVisible = false } }
            MenuItem { text: "缩小"; onTriggered: { zoomOut(); menuVisible = false } }
            MenuItem { text: "历史"; onTriggered: showHistoryPage() }
            MenuItem { text: "退出"; onTriggered: { requestExit(); menuVisible = false } }
        }
        MouseArea { anchors.fill: parent; anchors.margins: -10; z: -1; onClicked: menuVisible = false }
    }

    MouseArea { visible: menuVisible; anchors.fill: parent; z: 90; onClicked: menuVisible = false }

    component MenuItem: Rectangle {
        width: parent.width / 2; height: parent.height / 4; radius: 2
        color: ma2.pressed ? "#E0E0E0" : "transparent"
        property alias text: label.text; signal triggered()
        Text { id: label; anchors.centerIn: parent; font.pixelSize: 14; color: "#000000" }
        MouseArea { id: ma2; anchors.fill: parent; onClicked: parent.triggered() }
    }

    // ---- 历史页面 ----
    Loader {
        id: historyLoader; anchors.fill: parent; z: 95; active: false; source: "history.qml"
        onLoaded: {
            item.urlClicked.connect(function(url) { webView.loadUrl(url); closeHistory() })
            item.clearHistoryRequested.connect(function() { /* WPE 历史由 WebKit 管理 */ })
            item.backRequested.connect(closeHistory)
        }
        function show() { active = true } function hide() { active = false }
    }

    // ---- 设置页面 ----
    Loader {
        id: settingsLoader; anchors.fill: parent; z: 95; active: false; source: "settings.qml"
        onLoaded: {
            item.zoomPercent = Qt.binding(function() { return Math.round(webView.zoomFactor * 100) })
            item.searchTemplate = "https://cn.bing.com/search?q=%1"
            item.resetZoomRequested.connect(function() { webView.zoomFactor = 1.0 })
            item.editSearchTemplate.connect(function() {
                _createKeyboard("https://cn.bing.com/search?q=%1", function() {})
            })
            item.resetSettingsRequested.connect(function() {
                webView.zoomFactor = 1.0
                presets = [
                    { name: "一言", url: "https://v1.hitokoto.cn/?c=a&encode=text" },
                    { name: "必应", url: "https://cn.bing.com" },
                    { name: "哔哩哔哩", url: "https://www.bilibili.com" }
                ]
                saveState()
            })
            item.backRequested.connect(closeSettings)
        }
        function show() { active = true } function hide() { active = false }
    }

    // ---- 键盘辅助 ----
    YPagePopHelper {
        id: pagePopHelper; z: 99; property var containerItem: this
        isShowing: qmlGlobal.inputPageShowing; objectName: "from_WPEBrowser"
    }

    Component.onCompleted: {
        initDatabase()
        webView.loadUrl("https://cn.bing.com")
    }
    Component.onDestruction: saveState()
}
```

---

### Task 6: 适配 settings.qml

**File:** `wpewebkit-browser/settings.qml`（基于 `browser/settings.qml`，移除 WPE 不需要的选项）

- [ ] **Step 1: 编写 settings.qml**

```qml
import QtQuick 2.15

Rectangle {
    id: settingsRoot
    width: 320; height: 170; color: "#F5F5F5"

    signal backRequested()
    signal resetZoomRequested()
    signal editSearchTemplate()
    signal resetSettingsRequested()

    property int zoomPercent: 100
    property string searchTemplate: ""
    property bool showTemplateWarning: false

    MouseArea { anchors.fill: parent }

    TitleBar {
        id: titleBar
        width: parent.width; height: 20
        title: "设置"
    }

    Flickable {
        x: 0; y: 20; width: parent.width; height: parent.height - 50
        contentWidth: width; contentHeight: columnContent.height
        boundsBehavior: Flickable.StopAtBounds; clip: true

        Column {
            id: columnContent
            width: parent.width; spacing: 0

            Rectangle {
                width: parent.width; height: 30
                color: rza.pressed ? "#E0E0E0" : "transparent"
                Row {
                    anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
                    Text { anchors.verticalCenter: parent.verticalCenter; text: "重置网页缩放"; font.pixelSize: 13; color: "#000000" }
                    Text { anchors.verticalCenter: parent.verticalCenter; anchors.right: parent.right; text: "当前: " + zoomPercent + "%"; font.pixelSize: 13; color: "#000000" }
                }
                MouseArea { id: rza; anchors.fill: parent; onClicked: settingsRoot.resetZoomRequested() }
            }

            Rectangle {
                width: parent.width; height: 30
                color: sa.pressed ? "#E0E0E0" : "transparent"
                Row {
                    anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
                    Text { anchors.verticalCenter: parent.verticalCenter; text: "搜索引擎"; font.pixelSize: 13; color: "#000000" }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter; anchors.right: parent.right; width: 220
                        text: searchTemplate; font.pixelSize: 13; color: "#000000"
                        elide: Text.ElideRight; horizontalAlignment: Text.AlignRight
                    }
                }
                MouseArea { id: sa; anchors.fill: parent; onClicked: settingsRoot.editSearchTemplate() }
            }
        }
    }

    Rectangle {
        x: 0; y: parent.height - 30; width: parent.width; height: 30
        color: "#EEEEEE"; border.color: "#CCCCCC"; border.width: 0.5
        Row {
            anchors.fill: parent; anchors.leftMargin: 4; anchors.rightMargin: 4; spacing: 4
            Rectangle {
                width: 154; height: 26; anchors.verticalCenter: parent.verticalCenter; radius: 3
                color: ba.pressed ? "#D0D0D0" : "#E0E0E0"; border.color: "#B0B0B0"; border.width: 0.5
                Text { anchors.centerIn: parent; text: "返回"; font.pixelSize: 14; color: "#000000" }
                MouseArea { id: ba; anchors.fill: parent; onClicked: settingsRoot.backRequested() }
            }
            Rectangle {
                width: 154; height: 26; anchors.verticalCenter: parent.verticalCenter; radius: 3
                color: ra.pressed ? "#D0D0D0" : "#E0E0E0"; border.color: "#B0B0B0"; border.width: 0.5
                Text { anchors.centerIn: parent; text: "重置"; font.pixelSize: 14; color: "#FF0000" }
                MouseArea { id: ra; anchors.fill: parent; onClicked: settingsRoot.resetSettingsRequested() }
            }
        }
    }

    // 警告弹窗
    MouseArea { visible: showTemplateWarning; anchors.fill: parent; z: 109; onClicked: {} }
    Rectangle {
        visible: showTemplateWarning
        x: (parent.width - 240) / 2; y: (parent.height - 100) / 2; z: 110; width: 240; height: 100
        color: "#FFFFFF"; border.color: "#AAAAAA"; border.width: 1; radius: 6
        Column {
            anchors.centerIn: parent; spacing: 8
            Text { text: "需包含至少一个关键词占位符%1"; font.pixelSize: 13; color: "#000000"; horizontalAlignment: Text.AlignHCenter; width: 220; wrapMode: Text.Wrap }
            Text { text: "（点击关闭）"; font.pixelSize: 12; color: "#888888"; anchors.horizontalCenter: parent.horizontalCenter }
        }
        MouseArea { anchors.fill: parent; onClicked: showTemplateWarning = false }
    }
}
```

---

### Task 7: 最终验证

- [ ] 检查 `metadata.json` 完整性（id, name, version, main_qml, main_so）
- [ ] 检查所有 QML 文件 `import QtQuick 2.15`（非 3.0）
- [ ] 检查根 Rectangle `width: 320; height: 170`
- [ ] 检查 `signal backButtonClicked()` 存在
- [ ] 检查 C++ 导出符号（extern "C"）
- [ ] 检查 xmake.lua 目标名匹配
