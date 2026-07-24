#ifndef WEBVIEWITEM_H
#define WEBVIEWITEM_H

#include <QQuickItem>
#include <QSGSimpleTextureNode>
#include <QSGTexture>
#include <QQuickWindow>
#include <QImage>

// 前向声明 WPE 结构体（避免需要所有头文件）
struct wpe_view_backend;
typedef struct _WebKitWebView WebKitWebView;
typedef enum {
    WEBKIT_LOAD_STARTED,
    WEBKIT_LOAD_REDIRECTED,
    WEBKIT_LOAD_COMMITTED,
    WEBKIT_LOAD_FINISHED
} WebKitLoadEvent;

// WebKit URI request (前向声明)
typedef struct _WebKitURIRequest WebKitURIRequest;
typedef struct _WebKitNavigationAction WebKitNavigationAction;

class WebViewItem : public QQuickItem {
    Q_OBJECT
    Q_PROPERTY(QString title READ title NOTIFY titleChanged)
    Q_PROPERTY(QString url READ url NOTIFY urlChanged)
    Q_PROPERTY(bool loading READ isLoading NOTIFY loadingChanged)
    Q_PROPERTY(int loadProgress READ loadProgress NOTIFY loadProgressChanged)
    Q_PROPERTY(qreal zoomFactor READ zoomFactor WRITE setZoomFactor NOTIFY zoomFactorChanged)
    Q_PROPERTY(bool canGoBack READ canGoBack NOTIFY navigationChanged)
    Q_PROPERTY(bool canGoForward READ canGoForward NOTIFY navigationChanged)

public:
    explicit WebViewItem(QQuickItem* parent = nullptr);
    ~WebViewItem() override;

    QString title() const { return m_title; }
    QString url() const { return m_url; }
    bool isLoading() const { return m_loading; }
    int loadProgress() const { return m_loadProgress; }
    qreal zoomFactor() const { return m_zoomFactor; }
    void setZoomFactor(qreal factor);
    bool canGoBack() const;
    bool canGoForward() const;

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
    void navigationChanged();

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

    // 通过 GLib 信号连接到 WebKit 的静态回调
    static void onLoadChanged(WebKitWebView* view, int event, void* data);
    static void onTitleChanged(void* obj, void* pspec, void* data);
    static void onProgressChanged(void* obj, void* pspec, void* data);
    static void onUriChanged(void* obj, void* pspec, void* data);
};

#endif // WEBVIEWITEM_H
