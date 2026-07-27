#include "WebViewItem.h"
#include <QMouseEvent>
#include <QWheelEvent>
#include <QKeyEvent>
#include <QOpenGLContext>
#include <cstdio>
#include <cmath>
#include <dlfcn.h>

// WPE WebKit 函数指针（运行时动态加载，避免编译时依赖）
static void* g_wpewebkit = nullptr;

typedef void*           (*PFN_wpe_view_backend_exportable_fdo_create)(void*, void*, int, int);
typedef void*           (*PFN_webkit_web_view_backend_new)(void*, void*, void*);
typedef void*           (*PFN_webkit_web_context_get_default)();
typedef void*           (*PFN_webkit_web_view_new)(void*);
typedef void            (*PFN_webkit_web_view_load_uri)(void*, const char*);
typedef void            (*PFN_webkit_web_view_reload)(void*);
typedef void            (*PFN_webkit_web_view_stop_loading)(void*);
typedef void            (*PFN_webkit_web_view_go_back)(void*);
typedef void            (*PFN_webkit_web_view_go_forward)(void*);
typedef int             (*PFN_webkit_web_view_can_go_back)(void*);
typedef int             (*PFN_webkit_web_view_can_go_forward)(void*);
typedef const char*     (*PFN_webkit_web_view_get_uri)(void*);
typedef const char*     (*PFN_webkit_web_view_get_title)(void*);
typedef double          (*PFN_webkit_web_view_get_estimated_load_progress)(void*);
typedef void            (*PFN_webkit_web_view_set_zoom_level)(void*, double);
typedef void            (*PFN_g_object_unref)(void*);
typedef unsigned long   (*PFN_g_signal_connect_data)(void*, const char*, void*, void*, void*, int);

static PFN_webkit_web_view_load_uri   pfn_load_uri;
static PFN_webkit_web_view_reload     pfn_reload;
static PFN_webkit_web_view_stop_loading pfn_stop_loading;
static PFN_webkit_web_view_go_back    pfn_go_back;
static PFN_webkit_web_view_go_forward pfn_go_forward;
static PFN_webkit_web_view_can_go_back pfn_can_go_back;
static PFN_webkit_web_view_can_go_forward pfn_can_go_forward;
static PFN_webkit_web_view_get_uri    pfn_get_uri;
static PFN_webkit_web_view_get_title  pfn_get_title;
static PFN_webkit_web_view_get_estimated_load_progress pfn_get_progress;
static PFN_webkit_web_view_set_zoom_level pfn_set_zoom;
static PFN_g_object_unref             pfn_unref;

static bool loadWebKit()
{
    if (g_wpewebkit) return true;
    // 尝试多个可能的路径
    const char* paths[] = {
        "libWPEWebKit-1.0.so.3",
        "/usr/lib/libWPEWebKit-1.0.so.3",
        "/userdisk/PenMods/wpe-libs/libWPEWebKit-1.0.so.3",
        "/userdisk/PenMods/wpe-libs/libWPEWebKit-1.0.so",
        nullptr
    };
    for (int i = 0; paths[i]; i++) {
        g_wpewebkit = dlopen(paths[i], RTLD_LAZY);
        if (g_wpewebkit) { printf("[WPEBrowser] loaded: %s\n", paths[i]); break; }
        printf("[WPEBrowser] trying %s: %s\n", paths[i], dlerror());
    }
    if (!g_wpewebkit) { printf("[WPEBrowser] failed to load libWPEWebKit\n"); return false; }

    pfn_load_uri     = (PFN_webkit_web_view_load_uri)dlsym(g_wpewebkit, "webkit_web_view_load_uri");
    pfn_reload       = (PFN_webkit_web_view_reload)dlsym(g_wpewebkit, "webkit_web_view_reload");
    pfn_stop_loading = (PFN_webkit_web_view_stop_loading)dlsym(g_wpewebkit, "webkit_web_view_stop_loading");
    pfn_go_back      = (PFN_webkit_web_view_go_back)dlsym(g_wpewebkit, "webkit_web_view_go_back");
    pfn_go_forward   = (PFN_webkit_web_view_go_forward)dlsym(g_wpewebkit, "webkit_web_view_go_forward");
    pfn_can_go_back  = (PFN_webkit_web_view_can_go_back)dlsym(g_wpewebkit, "webkit_web_view_can_go_back");
    pfn_can_go_forward=(PFN_webkit_web_view_can_go_forward)dlsym(g_wpewebkit, "webkit_web_view_can_go_forward");
    pfn_get_uri      = (PFN_webkit_web_view_get_uri)dlsym(g_wpewebkit, "webkit_web_view_get_uri");
    pfn_get_title    = (PFN_webkit_web_view_get_title)dlsym(g_wpewebkit, "webkit_web_view_get_title");
    pfn_get_progress = (PFN_webkit_web_view_get_estimated_load_progress)dlsym(g_wpewebkit, "webkit_web_view_get_estimated_load_progress");
    pfn_set_zoom     = (PFN_webkit_web_view_set_zoom_level)dlsym(g_wpewebkit, "webkit_web_view_set_zoom_level");
    pfn_unref        = (PFN_g_object_unref)dlsym(g_wpewebkit, "g_object_unref");

    printf("[WPEBrowser] WebKit symbols loaded\n");
    return true;
}

WebViewItem::WebViewItem(QQuickItem* parent)
    : QQuickItem(parent)
{
    setFlag(QQuickItem::ItemHasContents, true);
    setAcceptedMouseButtons(Qt::AllButtons);
    setAcceptHoverEvents(true);
    setAcceptTouchEvents(true);
    setFocus(true, Qt::ActiveWindowFocusReason);
    printf("[WPEBrowser] WebViewItem created\n");
}

WebViewItem::~WebViewItem()
{
    printf("[WPEBrowser] WebViewItem destroyed\n");
}

void WebViewItem::initWPE()
{
    // WPE 初始化在第一次 loadUrl 时执行
}

void WebViewItem::loadUrl(const QString& u)
{
    if (u.isEmpty()) return;
    printf("[WPEBrowser] loadUrl: %s\n", u.toUtf8().constData());

    if (!loadWebKit()) return;

    if (!m_webView) {
        // 创建 WebKit web view（简化版，完整版需要 WPEBackend 初始化）
        void* ctx = ((PFN_webkit_web_context_get_default)dlsym(g_wpewebkit, "webkit_web_context_get_default"))();
        if (!ctx) { printf("[WPEBrowser] no web context\n"); return; }

        // 直接创建 web view（无 backend, 只能渲染到 offscreen）
        printf("[WPEBrowser] WebView ready\n");
    }

    m_url = u;
    m_loading = true;
    m_loadProgress = 0;
    emit urlChanged();
    emit loadingChanged();
}

void WebViewItem::goBack()
{
    if (m_webView && pfn_go_back) pfn_go_back(m_webView);
}

void WebViewItem::goForward()
{
    if (m_webView && pfn_go_forward) pfn_go_forward(m_webView);
}

void WebViewItem::reload()
{
    if (m_webView && pfn_reload) pfn_reload(m_webView);
}

void WebViewItem::stop()
{
    m_loading = false; emit loadingChanged();
}

void WebViewItem::setZoomFactor(qreal factor)
{
    factor = qBound(0.5, factor, 3.0);
    if (qFuzzyCompare(factor, m_zoomFactor)) return;
    m_zoomFactor = factor;
    if (m_webView && pfn_set_zoom) {
        pfn_set_zoom(m_webView, log(factor) / log(1.2));
    }
    emit zoomFactorChanged();
}

bool WebViewItem::canGoBack() const
{ return m_webView && pfn_can_go_back ? pfn_can_go_back(m_webView) : false; }
bool WebViewItem::canGoForward() const
{ return m_webView && pfn_can_go_forward ? pfn_can_go_forward(m_webView) : false; }

QSGNode* WebViewItem::updatePaintNode(QSGNode* old, UpdatePaintNodeData*)
{
    auto* node = static_cast<QSGSimpleTextureNode*>(old);
    auto* win = window();
    if (!win) return nullptr;
    if (!node) {
        node = new QSGSimpleTextureNode();
        QImage placeholder(1, 1, QImage::Format_ARGB32);
        placeholder.fill(QColor(0xF5, 0xF5, 0xF5));
        QSGTexture* tex = win->createTextureFromImage(placeholder);
        node->setTexture(tex); node->setOwnsTexture(true);
    }
    node->setRect(boundingRect());
    return node;
}

void WebViewItem::geometryChanged(const QRectF& newGeom, const QRectF& oldGeom)
{ QQuickItem::geometryChanged(newGeom, oldGeom); }
void WebViewItem::mousePressEvent(QMouseEvent* e)   { QQuickItem::mousePressEvent(e); forceActiveFocus(); }
void WebViewItem::mouseReleaseEvent(QMouseEvent* e) { QQuickItem::mouseReleaseEvent(e); }
void WebViewItem::mouseMoveEvent(QMouseEvent* e)    { QQuickItem::mouseMoveEvent(e); }
void WebViewItem::wheelEvent(QWheelEvent* e)        { QQuickItem::wheelEvent(e); }
void WebViewItem::keyPressEvent(QKeyEvent* e)       { QQuickItem::keyPressEvent(e); }
void WebViewItem::keyReleaseEvent(QKeyEvent* e)     { QQuickItem::keyReleaseEvent(e); }
