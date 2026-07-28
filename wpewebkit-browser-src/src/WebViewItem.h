#ifndef WEBVIEWITEM_H
#define WEBVIEWITEM_H

#include <QQuickItem>
#include <QSGSimpleTextureNode>
#include <QImage>
#include <QQuickWindow>

typedef struct _WebKitWebView WebKitWebView;

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
    void geometryChanged(const QRectF&, const QRectF&) override;
    void mousePressEvent(QMouseEvent*) override;
    void mouseReleaseEvent(QMouseEvent*) override;
    void mouseMoveEvent(QMouseEvent*) override;
    void wheelEvent(QWheelEvent*) override;
    void keyPressEvent(QKeyEvent*) override;
    void keyReleaseEvent(QKeyEvent*) override;

private:
    void initWPE();

    WebKitWebView* m_webView = nullptr;
    int m_viewWidth = 320, m_viewHeight = 150;
    QString m_title, m_url;
    bool m_loading = false;
    int m_loadProgress = 0;
    qreal m_zoomFactor = 1.0;
};

#endif
