#include "WebViewItem.h"

#include <QOpenGLContext>
#include <QOpenGLFunctions>
#include <QMouseEvent>
#include <QWheelEvent>
#include <QKeyEvent>
#include <cstdio>
#include <cmath>

// WPE / WebKit / EGL 头文件
#include <wpe/wpe.h>
#include <wpe/webkit.h>
#include <wpe/fdo.h>
#include <wpe/fdo-egl.h>
#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <GLES2/gl2.h>
#include <GLES2/gl2ext.h>

// ============================================================
// 全局 EGL 函数指针（运行时获取）
// ============================================================
static PFNGLEGLIMAGETARGETTEXTURE2DOESPROC g_glEGLImageTargetTexture2DOES = nullptr;

// ============================================================
// 帧数据：WPE 每渲染一帧通过回调传给 Qt 主线程
// ============================================================
struct FrameData {
    EGLImageKHR image = EGL_NO_IMAGE_KHR;
    int width = 0;
    int height = 0;
    bool dirty = false;
};

// 每个 WebViewItem 实例一份
static thread_local FrameData* g_currentFrame = nullptr;

// ============================================================
// WPE backend export client callbacks
// ============================================================

// WPE 导出 EGLImage 的回调
static void onWPEExportEGLImage(void* data, EGLImageKHR image)
{
    auto* self = static_cast<WebViewItem*>(data);
    if (!g_currentFrame) return;

    g_currentFrame->image = image;
    g_currentFrame->dirty = true;

    // 触发 Qt 重绘
    QMetaObject::invokeMethod(self, "update", Qt::QueuedConnection);
}

// WPE 导出 DMA-BUF 的回调（备用）
static void onWPEExportDMABuf(void* data,
    unsigned format, unsigned n_planes,
    int fds[4], unsigned strides[4], unsigned offsets[4],
    uint64_t modifiers[4])
{
    // 设备若支持 DMA-BUF 传输，可以走此路径（更高效）
    // 当前实现走 EGLImage 路径
}

// WPE backend client 结构
static struct wpe_view_backend_exportable_fdo_client s_wpeClient = {
    /* export_egl_image       */ onWPEExportEGLImage,
    /* export_fdo_egl_image   */ nullptr,  // 留空
    /* export_fdo_dmabuf      */ onWPEExportDMABuf,
    /* padding                */ nullptr, nullptr, nullptr,
};

// ============================================================
// GLib 信号回调（运行在 WPE 线程，通过 QMetaObject 转发到主线程）
// ============================================================

static void onLoadChangedCB(WebKitWebView*, WebKitLoadEvent event, gpointer data)
{
    auto* self = static_cast<WebViewItem*>(data);
    QMetaObject::invokeMethod(self, [self, event]() {
        switch (event) {
        case WEBKIT_LOAD_STARTED:
            self->setProperty("loading", true);
            self->setProperty("title", QString());
            break;
        case WEBKIT_LOAD_FINISHED: {
            self->setProperty("loading", false);
            self->setProperty("loadProgress", 100);
            // URL 已通过 notify::uri 更新
            break;
        }
        default:
            break;
        }
    }, Qt::QueuedConnection);
}

static void onNotifyTitleCB(GObject* obj, void*, void* data)
{
    auto* self = static_cast<WebViewItem*>(data);
    const gchar* title = webkit_web_view_get_title(WEBKIT_WEB_VIEW(obj));
    QString t = title ? QString::fromUtf8(title) : QString();
    QMetaObject::invokeMethod(self, [self, t]() {
        self->setProperty("title", t);
    }, Qt::QueuedConnection);
}

static void onNotifyProgressCB(GObject* obj, void*, void* data)
{
    auto* self = static_cast<WebViewItem*>(data);
    gdouble progress = webkit_web_view_get_estimated_load_progress(WEBKIT_WEB_VIEW(obj));
    int p = static_cast<int>(progress * 100.0);
    QMetaObject::invokeMethod(self, [self, p]() {
        self->setProperty("loadProgress", p);
    }, Qt::QueuedConnection);
}

static void onNotifyUriCB(GObject* obj, void*, void* data)
{
    auto* self = static_cast<WebViewItem*>(data);
    const gchar* uri = webkit_web_view_get_uri(WEBKIT_WEB_VIEW(obj));
    QString u = uri ? QString::fromUtf8(uri) : QString();
    QMetaObject::invokeMethod(self, [self, u]() {
        self->setProperty("url", u);
    }, Qt::QueuedConnection);
}

// ============================================================
// WebViewItem 实现
// ============================================================

WebViewItem::WebViewItem(QQuickItem* parent)
    : QQuickItem(parent)
{
    setFlag(QQuickItem::ItemHasContents, true);
    setAcceptedMouseButtons(Qt::AllButtons);
    setAcceptHoverEvents(true);
    setAcceptTouchEvents(true);
    setFocus(true, Qt::ActiveWindowFocusReason);

    // 分配帧数据
    g_currentFrame = new FrameData();

    // 初始化 EGL/GLES 扩展
    g_glEGLImageTargetTexture2DOES =
        (PFNGLEGLIMAGETARGETTEXTURE2DOESPROC)eglGetProcAddress("glEGLImageTargetTexture2DOES");

    printf("[WPEBrowser] WebViewItem created\n");
    initWPE();
}

WebViewItem::~WebViewItem()
{
    cleanupWPE();
    delete g_currentFrame;
    g_currentFrame = nullptr;
    printf("[WPEBrowser] WebViewItem destroyed\n");
}

void WebViewItem::initWPE()
{
    // 步骤1: 创建 wpebackend-fdo 后端
    // wpe_view_backend_exportable_fdo_create 创建一个能导出 EGLImage 的后端
    m_wpeBackend = wpe_view_backend_exportable_fdo_create(
        &s_wpeClient,   // client callbacks
        this,           // user data
        m_viewWidth,    // initial width
        m_viewHeight    // initial height
    );

    if (!m_wpeBackend) {
        printf("[WPEBrowser] ERROR: Failed to create WPE backend\n");
        return;
    }
    printf("[WPEBrowser] WPE backend created (%dx%d)\n", m_viewWidth, m_viewHeight);

    // 步骤2: 创建 WebKit web view backend
    WebKitWebViewBackend* wkBackend = webkit_web_view_backend_new(
        m_wpeBackend,
        [](gpointer) {
            // cleanup callback - 由 WebKit 在 web view 销毁时调用
        },
        this
    );

    // 步骤3: 创建 WebKitWebView（使用 GObject API）
    m_webView = WEBKIT_WEB_VIEW(g_object_new(
        WEBKIT_TYPE_WEB_VIEW,
        "backend", wkBackend,
        "web-context", webkit_web_context_get_default(),
        "is-controlled-by-automation", FALSE,
        nullptr
    ));

    if (!m_webView) {
        printf("[WPEBrowser] ERROR: Failed to create WebKitWebView\n");
        return;
    }

    // 步骤4: 连接 GLib 信号
    g_signal_connect(m_webView, "load-changed",
                     G_CALLBACK(onLoadChangedCB), this);
    g_signal_connect(m_webView, "notify::title",
                     G_CALLBACK(onNotifyTitleCB), this);
    g_signal_connect(m_webView, "notify::estimated-load-progress",
                     G_CALLBACK(onNotifyProgressCB), this);
    g_signal_connect(m_webView, "notify::uri",
                     G_CALLBACK(onNotifyUriCB), this);

    // 步骤5: 设置初始背景色和缩放
    WebKitColor bgColor = { 255, 255, 255, 255 }; // 白色
    webkit_web_view_set_background_color(m_webView, &bgColor);
    webkit_web_view_set_zoom_level(m_webView, 0.0); // 100%

    // 设置 User-Agent（移动端风格，适合 320px 宽屏）
    webkit_settings_set_user_agent(
        webkit_web_view_get_settings(m_webView),
        "Mozilla/5.0 (Linux; ARM; PenMods) AppleWebKit/605.1.15 (KHTML, like Gecko) "
        "Version/1.0 WPEWebKit/2.0 Mobile/15E148"
    );

    printf("[WPEBrowser] WebKitWebView initialized successfully\n");
}

void WebViewItem::cleanupWPE()
{
    if (m_webView) {
        webkit_web_view_stop_loading(m_webView);
        g_object_unref(m_webView);
        m_webView = nullptr;
    }
    // m_wpeBackend 由 WebKitWebViewBackend 持有，销毁 webView 时自动释放
    m_wpeBackend = nullptr;
}

// ============================================================
// 公共 API
// ============================================================

void WebViewItem::loadUrl(const QString& u)
{
    if (!m_webView || u.isEmpty()) return;
    printf("[WPEBrowser] Loading: %s\n", u.toUtf8().constData());
    webkit_web_view_load_uri(m_webView, u.toUtf8().constData());
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
    factor = qBound(0.5, factor, 3.0);
    if (qFuzzyCompare(factor, m_zoomFactor)) return;

    m_zoomFactor = factor;
    if (m_webView) {
        // WebKit zoom level = ln(factor) / ln(1.2)
        double level = std::log(static_cast<double>(factor)) / std::log(1.2);
        webkit_web_view_set_zoom_level(m_webView, level);
    }
    emit zoomFactorChanged();
}

bool WebViewItem::canGoBack() const
{
    return m_webView ? webkit_web_view_can_go_back(m_webView) : false;
}

bool WebViewItem::canGoForward() const
{
    return m_webView ? webkit_web_view_can_go_forward(m_webView) : false;
}

// ============================================================
// 渲染管线：updatePaintNode
// ============================================================

QSGNode* WebViewItem::updatePaintNode(QSGNode* old, UpdatePaintNodeData*)
{
    auto* node = static_cast<QSGSimpleTextureNode*>(old);
    auto* win = window();

    if (!win) {
        // 窗口未就绪，返回空节点
        delete node;
        return nullptr;
    }

    // 没有可渲染帧
    if (!g_currentFrame || g_currentFrame->image == EGL_NO_IMAGE_KHR) {
        if (!node) {
            node = new QSGSimpleTextureNode();
            QImage placeholder(1, 1, QImage::Format_ARGB32);
            placeholder.fill(Qt::white);
            QSGTexture* tex = win->createTextureFromImage(placeholder);
            node->setTexture(tex);
            node->setOwnsTexture(true);
        }
        node->setRect(boundingRect());
        return node;
    }

    // 有新帧需要更新纹理
    if (g_currentFrame->dirty) {
        if (!node) {
            node = new QSGSimpleTextureNode();
        }

        // 获取当前 OpenGL 上下文
        QOpenGLContext* ctx = win->openglContext();
        if (ctx && ctx->isValid() && g_glEGLImageTargetTexture2DOES) {
            QOpenGLFunctions* gl = ctx->functions();

            // 释放旧纹理
            if (node->texture() && node->ownsTexture()) {
                delete node->texture();
            }

            // 创建新 GL 纹理并绑定 EGLImage
            GLuint texId = 0;
            gl->glGenTextures(1, &texId);
            gl->glBindTexture(GL_TEXTURE_2D, texId);
            gl->glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
            gl->glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
            gl->glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
            gl->glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

            // 将 EGLImage 绑定为 GL 纹理
            g_glEGLImageTargetTexture2DOES(GL_TEXTURE_2D,
                                           (GLeglImageOES)g_currentFrame->image);

            gl->glBindTexture(GL_TEXTURE_2D, 0);

            // 通过 native texture ID 创建 QSGTexture
            QSGTexture* qsgTex = win->createTextureFromNativeObject(
                QQuickWindow::NativeObjectTexture,
                &texId, 0,
                QSize(m_viewWidth, m_viewHeight),
                QQuickWindow::TextureHasAlphaChannel
            );

            if (qsgTex) {
                node->setTexture(qsgTex);
                node->setOwnsTexture(true);
            }

            printf("[WPEBrowser] Frame updated via EGLImage -> GL texture\n");
        }

        g_currentFrame->dirty = false;
    }

    node->setRect(boundingRect());
    return node;
}

// ============================================================
// 几何变更
// ============================================================

void WebViewItem::geometryChanged(const QRectF& newGeom, const QRectF& oldGeom)
{
    QQuickItem::geometryChanged(newGeom, oldGeom);
    int w = static_cast<int>(newGeom.width());
    int h = static_cast<int>(newGeom.height());
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

// ============================================================
// 输入事件转发（将 Qt 事件转为 WPE 输入）
// ============================================================

// WPE 输入事件结构体
struct wpe_input_touch_event_raw {
    int type;       // 0=down, 1=move, 2=up
    int id;
    int x, y;
};

struct wpe_input_keyboard_event {
    // 键盘事件结构体（具体字段取决于 WPE 版本）
};

// 辅助：发送鼠标/触摸事件到 WPE
static void dispatchTouchEvent(struct wpe_view_backend* backend,
                                int type, int id, int x, int y)
{
    // WPE 1.x API: wpe_view_backend_dispatch_touch_event
    // 注意：此 API 可能因 WPE 版本不同而异
    // 以下是标准 WPE 后端触摸事件分发方式

    // 通过 wpe_input_* 系列 API 发送
    // 具体实现取决于 WPE 版本，这里使用常用的 dispatch 方式
    if (!backend) return;

    // wpe_view_backend_dispatch_pointer_event (WPE 2.x)
    // 或 wpe_view_backend_dispatch_touch_event (WPE 1.x)
    // 这里使用兼容方式
    struct {
        int type;
        int x, y;
        int button;
        int state;
        uint32_t time;
    } pointerEvent;

    pointerEvent.time = 0;
    pointerEvent.x = x;
    pointerEvent.y = y;
    pointerEvent.button = 1;     // left button
    pointerEvent.state = type;   // 0=released, 1=pressed
    pointerEvent.type = (type == 2) ? 2 : (type == 0 ? 0 : 1);

    // wpe_view_backend_dispatch_pointer_event 不是标准 API
    // 实际设备上需根据 WPE 版本使用对应的 dispatch 函数
    // 此处保留接口，实际编译时替换
    (void)backend;
    (void)pointerEvent;
}

void WebViewItem::mousePressEvent(QMouseEvent* event)
{
    QQuickItem::mousePressEvent(event);
    if (m_wpeBackend) {
        QPointF pos = event->pos();
        dispatchTouchEvent(m_wpeBackend, 1, 0,
                          static_cast<int>(pos.x()),
                          static_cast<int>(pos.y()));
    }
    forceActiveFocus();
}

void WebViewItem::mouseReleaseEvent(QMouseEvent* event)
{
    QQuickItem::mouseReleaseEvent(event);
    if (m_wpeBackend) {
        QPointF pos = event->pos();
        dispatchTouchEvent(m_wpeBackend, 0, 0,
                          static_cast<int>(pos.x()),
                          static_cast<int>(pos.y()));
    }
}

void WebViewItem::mouseMoveEvent(QMouseEvent* event)
{
    QQuickItem::mouseMoveEvent(event);
    if (m_wpeBackend) {
        QPointF pos = event->pos();
        dispatchTouchEvent(m_wpeBackend, 2, 0,
                          static_cast<int>(pos.x()),
                          static_cast<int>(pos.y()));
    }
}

void WebViewItem::wheelEvent(QWheelEvent* event)
{
    QQuickItem::wheelEvent(event);
    // 滚轮事件可转为缩放或滚动，这里不做处理由 WPE 内部处理触摸滚动
    event->accept();
}

void WebViewItem::keyPressEvent(QKeyEvent* event)
{
    QQuickItem::keyPressEvent(event);
    // 键盘事件转发到 WPE（若设备外接键盘）
    const char* text = event->text().toUtf8().constData();
    if (text[0] && m_wpeBackend) {
        // 使用 wpe_input_keyboard_* API 转发
        // 具体 API 因版本而异
    }
}

void WebViewItem::keyReleaseEvent(QKeyEvent* event)
{
    QQuickItem::keyReleaseEvent(event);
}
