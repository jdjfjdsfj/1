#include "WebViewItem.h"
#include <QMouseEvent>
#include <QWheelEvent>
#include <QKeyEvent>
#include <QOpenGLContext>
#include <cstdio>
#include <cmath>
#include <wpe/webkit.h>
#include <wpe/fdo.h>

WebViewItem::WebViewItem(QQuickItem* parent)
    : QQuickItem(parent)
{
    setFlag(QQuickItem::ItemHasContents, true);
    setAcceptedMouseButtons(Qt::AllButtons);
    setAcceptHoverEvents(true);
    setAcceptTouchEvents(true);
    setFocus(true, Qt::ActiveWindowFocusReason);
    printf("[WPEBrowser] WebViewItem created\n");
    initWPE();
}

WebViewItem::~WebViewItem()
{
    if (m_webView) {
        webkit_web_view_stop_loading(m_webView);
        g_object_unref(m_webView);
    }
    printf("[WPEBrowser] WebViewItem destroyed\n");
}

static void onLoadChanged(WebKitWebView* view, WebKitLoadEvent event, gpointer data)
{
    auto* self = static_cast<WebViewItem*>(data);
    if (event == WEBKIT_LOAD_COMMITTED) {
        const char* uri = webkit_web_view_get_uri(view);
        if (uri) { self->m_url = QString::fromUtf8(uri); emit self->urlChanged(); }
    }
    if (event == WEBKIT_LOAD_FINISHED) {
        self->m_loading = false; self->m_loadProgress = 100;
        emit self->loadingChanged(); emit self->loadProgressChanged();
    }
}

static void onTitleChanged(GObject* obj, GParamSpec*, gpointer data)
{
    auto* self = static_cast<WebViewItem*>(data);
    const char* t = webkit_web_view_get_title(WEBKIT_WEB_VIEW(obj));
    if (t) { self->m_title = QString::fromUtf8(t); emit self->titleChanged(); }
}

void WebViewItem::initWPE()
{
    // 创建 web context
    WebKitWebContext* ctx = webkit_web_context_get_default();

    // 创建 backend
    m_webView = WEBKIT_WEB_VIEW(webkit_web_view_new(ctx));

    if (!m_webView) {
        printf("[WPEBrowser] Failed to create WebView\n");
        return;
    }

    g_signal_connect(m_webView, "load-changed", G_CALLBACK(onLoadChanged), this);
    g_signal_connect(m_webView, "notify::title", G_CALLBACK(onTitleChanged), this);

    WebKitColor bg = { 255, 255, 255, 255 };
    webkit_web_view_set_background_color(m_webView, &bg);

    printf("[WPEBrowser] WebView initialized\n");
}

void WebViewItem::loadUrl(const QString& u)
{
    if (u.isEmpty() || !m_webView) return;
    m_url = u;
    m_loading = true;
    m_loadProgress = 0;
    webkit_web_view_load_uri(m_webView, u.toUtf8().constData());
    emit urlChanged();
    emit loadingChanged();
}

void WebViewItem::goBack()    { if (m_webView) webkit_web_view_go_back(m_webView); }
void WebViewItem::goForward() { if (m_webView) webkit_web_view_go_forward(m_webView); }
void WebViewItem::reload()    { if (m_webView) webkit_web_view_reload(m_webView); }
void WebViewItem::stop()      { if (m_webView) { webkit_web_view_stop_loading(m_webView); m_loading = false; emit loadingChanged(); } }

void WebViewItem::setZoomFactor(qreal factor)
{
    factor = qBound(0.5, factor, 3.0);
    if (qFuzzyCompare(factor, m_zoomFactor)) return;
    m_zoomFactor = factor;
    if (m_webView) webkit_web_view_set_zoom_level(m_webView, log(factor) / log(1.2));
    emit zoomFactorChanged();
}

bool WebViewItem::canGoBack() const
    { return m_webView && webkit_web_view_can_go_back(m_webView); }
bool WebViewItem::canGoForward() const
    { return m_webView && webkit_web_view_can_go_forward(m_webView); }

QSGNode* WebViewItem::updatePaintNode(QSGNode* old, UpdatePaintNodeData*)
{
    auto* node = static_cast<QSGSimpleTextureNode*>(old);
    auto* win = window();
    if (!win) return nullptr;

    if (!node) {
        node = new QSGSimpleTextureNode();
        QImage placeholder(m_viewWidth > 0 ? m_viewWidth : 320,
                           m_viewHeight > 0 ? m_viewHeight : 150,
                           QImage::Format_ARGB32);
        placeholder.fill(QColor(0xF5, 0xF5, 0xF5));
        QSGTexture* tex = win->createTextureFromImage(placeholder);
        node->setTexture(tex); node->setOwnsTexture(true);
    }
    node->setRect(boundingRect());
    return node;
}

void WebViewItem::geometryChanged(const QRectF& newGeom, const QRectF& oldGeom)
{
    QQuickItem::geometryChanged(newGeom, oldGeom);
    m_viewWidth = newGeom.width();
    m_viewHeight = newGeom.height();
}

void WebViewItem::mousePressEvent(QMouseEvent* e)   { QQuickItem::mousePressEvent(e); forceActiveFocus(); }
void WebViewItem::mouseReleaseEvent(QMouseEvent* e) { QQuickItem::mouseReleaseEvent(e); }
void WebViewItem::mouseMoveEvent(QMouseEvent* e)    { QQuickItem::mouseMoveEvent(e); }
void WebViewItem::wheelEvent(QWheelEvent* e)        { QQuickItem::wheelEvent(e); }
void WebViewItem::keyPressEvent(QKeyEvent* e)       { QQuickItem::keyPressEvent(e); }
void WebViewItem::keyReleaseEvent(QKeyEvent* e)     { QQuickItem::keyReleaseEvent(e); }
