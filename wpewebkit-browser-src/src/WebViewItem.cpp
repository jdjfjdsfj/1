#include "WebViewItem.h"
#include <QMouseEvent>
#include <QWheelEvent>
#include <QKeyEvent>
#include <cstdio>
#include <cmath>

// WPE WebKit API 直接声明（无需头文件，链接时由 libWPEWebKit-1.0 解析）
extern "C" {
    struct _WebKitWebContext;
    typedef struct _WebKitWebView WebKitWebView;
    typedef enum { WEBKIT_LOAD_STARTED, WEBKIT_LOAD_REDIRECTED, WEBKIT_LOAD_COMMITTED, WEBKIT_LOAD_FINISHED } WebKitLoadEvent;
    typedef struct { unsigned char r,g,b,a; } WebKitColor;

    _WebKitWebContext*  webkit_web_context_get_default(void);
    WebKitWebView*      webkit_web_view_new(_WebKitWebContext*);
    void                webkit_web_view_load_uri(WebKitWebView*, const char*);
    void                webkit_web_view_reload(WebKitWebView*);
    void                webkit_web_view_stop_loading(WebKitWebView*);
    void                webkit_web_view_go_back(WebKitWebView*);
    void                webkit_web_view_go_forward(WebKitWebView*);
    int                 webkit_web_view_can_go_back(WebKitWebView*);
    int                 webkit_web_view_can_go_forward(WebKitWebView*);
    const char*         webkit_web_view_get_uri(WebKitWebView*);
    const char*         webkit_web_view_get_title(WebKitWebView*);
    double              webkit_web_view_get_estimated_load_progress(WebKitWebView*);
    void                webkit_web_view_set_zoom_level(WebKitWebView*, double);
    void                webkit_web_view_set_background_color(WebKitWebView*, WebKitColor*);
    void                g_object_unref(void*);
    unsigned long       g_signal_connect_data(void*, const char*, void*, void*, void*, int);
    #define G_CALLBACK(f) ((void(*)(void))(f))
}

WebViewItem::WebViewItem(QQuickItem* parent) : QQuickItem(parent) {
    setFlag(QQuickItem::ItemHasContents, true);
    setAcceptedMouseButtons(Qt::AllButtons);
    setAcceptHoverEvents(true);
    setAcceptTouchEvents(true);
    setFocus(true, Qt::ActiveWindowFocusReason);
    printf("[WPEBrowser] WebViewItem created\n");
    initWPE();
}

WebViewItem::~WebViewItem() {
    if (m_webView) { webkit_web_view_stop_loading(m_webView); g_object_unref(m_webView); }
    printf("[WPEBrowser] WebViewItem destroyed\n");
}

static void onLoadChanged(WebKitWebView* view, WebKitLoadEvent event, WebViewItem* self) {
    if (event == WEBKIT_LOAD_COMMITTED) {
        const char* uri = webkit_web_view_get_uri(view);
        if (uri) self->setProperty("url", QString::fromUtf8(uri));
    }
    if (event == WEBKIT_LOAD_FINISHED) {
        self->setProperty("loading", false);
        self->setProperty("loadProgress", 100);
    }
}

void WebViewItem::initWPE() {
    auto* ctx = webkit_web_context_get_default();
    m_webView = webkit_web_view_new(ctx);
    if (!m_webView) { printf("[WPEBrowser] Failed to create WebView\n"); return; }
    g_signal_connect_data(m_webView, "load-changed", (void*)onLoadChanged, this, nullptr, 0);
    WebKitColor bg = {255,255,255,255};
    webkit_web_view_set_background_color(m_webView, &bg);
    printf("[WPEBrowser] WebView ready\n");
}

void WebViewItem::loadUrl(const QString& u) {
    if (u.isEmpty() || !m_webView) return;
    setProperty("url", u);
    setProperty("loading", true);
    setProperty("loadProgress", 0);
    webkit_web_view_load_uri(m_webView, u.toUtf8().constData());
}

void WebViewItem::goBack()    { if (m_webView) webkit_web_view_go_back(m_webView); }
void WebViewItem::goForward() { if (m_webView) webkit_web_view_go_forward(m_webView); }
void WebViewItem::reload()    { if (m_webView) webkit_web_view_reload(m_webView); }
void WebViewItem::stop()      { if (m_webView) { webkit_web_view_stop_loading(m_webView); setProperty("loading", false); } }

void WebViewItem::setZoomFactor(qreal factor) {
    factor = qBound(0.5, factor, 3.0);
    if (qFuzzyCompare(factor, m_zoomFactor)) return;
    m_zoomFactor = factor;
    if (m_webView) webkit_web_view_set_zoom_level(m_webView, log(factor)/log(1.2));
    emit zoomFactorChanged();
}

bool WebViewItem::canGoBack()    { return m_webView && webkit_web_view_can_go_back(m_webView); }
bool WebViewItem::canGoForward() { return m_webView && webkit_web_view_can_go_forward(m_webView); }

QSGNode* WebViewItem::updatePaintNode(QSGNode* old, UpdatePaintNodeData*) {
    auto* node = static_cast<QSGSimpleTextureNode*>(old);
    auto* win = window();
    if (!win) return nullptr;
    if (!node) {
        node = new QSGSimpleTextureNode();
        QImage placeholder(m_viewWidth>0?m_viewWidth:320, m_viewHeight>0?m_viewHeight:150, QImage::Format_ARGB32);
        placeholder.fill(QColor(0xF5,0xF5,0xF5));
        QSGTexture* tex = win->createTextureFromImage(placeholder);
        node->setTexture(tex); node->setOwnsTexture(true);
    }
    node->setRect(boundingRect());
    return node;
}

void WebViewItem::geometryChanged(const QRectF& n, const QRectF& o)
{ QQuickItem::geometryChanged(n,o); m_viewWidth=n.width(); m_viewHeight=n.height(); }
void WebViewItem::mousePressEvent(QMouseEvent* e)   { QQuickItem::mousePressEvent(e); forceActiveFocus(); }
void WebViewItem::mouseReleaseEvent(QMouseEvent* e) { QQuickItem::mouseReleaseEvent(e); }
void WebViewItem::mouseMoveEvent(QMouseEvent* e)    { QQuickItem::mouseMoveEvent(e); }
void WebViewItem::wheelEvent(QWheelEvent* e)        { QQuickItem::wheelEvent(e); }
void WebViewItem::keyPressEvent(QKeyEvent* e)       { QQuickItem::keyPressEvent(e); }
void WebViewItem::keyReleaseEvent(QKeyEvent* e)     { QQuickItem::keyReleaseEvent(e); }
