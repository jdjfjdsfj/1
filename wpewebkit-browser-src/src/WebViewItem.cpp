#include "WebViewItem.h"
#include <QMouseEvent>
#include <QWheelEvent>
#include <QKeyEvent>
#include <cstdio>
#include <cmath>

// ============================================================
// WebViewItem — WPE 浏览器视图 QQuickItem（编译桩版本）
//
// 设备运行需要: libwpe, libwpebackend-fdo, libwpewebkit
// 这些库在设备上由 PenMods 宿主提供，编译时只需头文件声明
// ============================================================

WebViewItem::WebViewItem(QQuickItem* parent)
    : QQuickItem(parent)
{
    setFlag(QQuickItem::ItemHasContents, true);
    setAcceptedMouseButtons(Qt::AllButtons);
    setAcceptHoverEvents(true);
    setAcceptTouchEvents(true);
    setFocus(true, Qt::ActiveWindowFocusReason);
    printf("[WPEBrowser] WebViewItem created (stub)\n");
}

WebViewItem::~WebViewItem()
{
    printf("[WPEBrowser] WebViewItem destroyed\n");
}

// ---- 导航 ----
void WebViewItem::loadUrl(const QString& u)
{
    printf("[WPEBrowser] loadUrl: %s\n", u.toUtf8().constData());
    m_url = u;
    m_loading = true;
    m_loadProgress = 0;
    emit urlChanged();
    emit loadingChanged();
    // 真实实现需要 webkit_web_view_load_uri(m_webView, ...)
}

void WebViewItem::goBack()    { /* webkit_web_view_go_back(m_webView) */ }
void WebViewItem::goForward() { /* webkit_web_view_go_forward(m_webView) */ }
void WebViewItem::reload()    { /* webkit_web_view_reload(m_webView) */ }

void WebViewItem::stop()
{
    m_loading = false;
    emit loadingChanged();
}

void WebViewItem::setZoomFactor(qreal factor)
{
    factor = qBound(0.5, factor, 3.0);
    if (qFuzzyCompare(factor, m_zoomFactor)) return;
    m_zoomFactor = factor;
    emit zoomFactorChanged();
}

bool WebViewItem::canGoBack() const    { return false; }
bool WebViewItem::canGoForward() const { return false; }

// ---- 渲染（桩，真实实现在 updatePaintNode 中渲染 EGL 纹理） ----
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
        node->setTexture(tex);
        node->setOwnsTexture(true);
    }
    node->setRect(boundingRect());
    return node;
}

void WebViewItem::geometryChanged(const QRectF& newGeom, const QRectF& oldGeom)
{
    QQuickItem::geometryChanged(newGeom, oldGeom);
}

// ---- 输入事件（转发给 WPE，桩版本仅接受） ----
void WebViewItem::mousePressEvent(QMouseEvent* e)   { QQuickItem::mousePressEvent(e); forceActiveFocus(); }
void WebViewItem::mouseReleaseEvent(QMouseEvent* e) { QQuickItem::mouseReleaseEvent(e); }
void WebViewItem::mouseMoveEvent(QMouseEvent* e)    { QQuickItem::mouseMoveEvent(e); }
void WebViewItem::wheelEvent(QWheelEvent* e)        { QQuickItem::wheelEvent(e); }
void WebViewItem::keyPressEvent(QKeyEvent* e)       { QQuickItem::keyPressEvent(e); }
void WebViewItem::keyReleaseEvent(QKeyEvent* e)     { QQuickItem::keyReleaseEvent(e); }
