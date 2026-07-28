# 60s

来自GitHub开源仓库：`https://github.com/vikiboss/60s`
60s API文档：`https://docs.60s-api.viki.moe`

## 1. 条目系统概览（menuItems）

首页卡片数据来自根对象属性：

```qml
property var menuItems: [
  { name, endpoint, icon, accent, action? },
  ...
]
```

每个条目（卡片）至少建议包含：

- `name`：显示标题（也用于内容页顶栏标题）
- `endpoint`：接口路径（会拼到 `apiBaseUrl + apiPrefix + "/" + endpoint`）
- `icon`：卡片上显示的图标（这里用 emoji）
- `accent`：卡片顶部色条颜色（字符串，如 `"#4DA3FF"`）
- `action`（可选）：自定义处理函数（函数本体或函数名字符串）

点击卡片里的“打开”按钮触发：

```qml
fetchContent(modelData.endpoint)
```

然后内部会找到对应条目并调用：

```qml
runCustomActionOrDefaultFetch(selectedItem, endpoint)
```

> 注意：**B站热搜** 与 **懂车帝** 两个条目使用自定义 action（`getBili` / `getDongchedi`），不走默认请求：
>
> - B站热搜：上游 `/v2/bili` 在官方实例上已 500，先请求主站，失败后自动回退社区镜像 `https://60s.7se.cn/v2/bili`（json）。
> - 懂车帝：上游 `/v2/dongchedi` 已返回空数据（其抓取的页面失效），直接请求懂车帝官方接口 `https://www.dongchedi.com/motor/searchpage/launcher/main/v1/` 取热搜榜，失败再回退 60s 接口。

---

## 2.1 内容页图片点击查看大图

内容页不再用单个 `Text` 渲染整段 markdown，而是由 `parseSegments()` 把内容切成**文字段 + 图片段**（`contentSegments`），图片段用独立的 `Image` 渲染，因此可点击。

点击图片时的打开逻辑（`openImageWithSystemViewer()`，参考 bili_plugin 的实现）：

1. 系统 `FileManagerImageViewer` 只能打开**本地文件**，所以远程图先用宿主注入的 `shell` 全局对象（`shell.execAsync` + `curl`，与 `shell_demo` 相同）下载到 `/tmp/60s_images/`；`data:` URI（如二维码条目）用 `base64 -d` 解码成文件；本地路径直接使用。
2. 然后调用宿主注入的 `imageViewer.open(localPath)`，并用本页自带的 `id_pop_container.show("qrc:/qml/audiopages/FileManagerImageViewer.qml")` 弹出系统图片查看器（弹出容器代码复制自 `bili_plugin/qml/pages/CommentsPage.qml`）。
3. 兜底：宿主未注入 `imageViewer` / `shell`，或下载失败时，回退到应用内全屏预览覆盖层（点击关闭）。返回键在预览打开时优先关闭预览。

---

## 2. 默认请求模式（最简单：只加一条 menuItems）

### 2.1 适用场景
- 接口直接返回 **Markdown 文本**
- 不需要对返回数据进行 JSON 解析/二次加工
- 你希望统一走 `encoding=markdown` 与缓存规避参数

### 2.2 默认请求会请求什么 URL
默认请求调用：

- `buildUrlWithParams(endpoint)` 会拼上固定参数：
  - `encoding=markdown`
  - 可选缓存规避：`_t=<timestamp>`（由 `enableCacheBuster` 与 `cacheBusterKey` 控制）

最终形如：

```
{apiBaseUrl}{apiPrefix}/{endpoint}?encoding=markdown&_t=171...
```

### 2.3 添加条目示例
在 `menuItems` 数组中新增一个对象即可：

```qml
{
  name: "历史上的今天",
  endpoint: "history",
  icon: "📅",
  accent: "#10B981"
}
```

不写 `action` 就会自动使用默认请求并把返回内容作为 Markdown 显示在内容页。

---

## 3. 自定义模式（action 接管：请求、解析、生成 Markdown）

### 3.1 适用场景
- 接口返回的是 **JSON**
- 需要把 JSON 格式化成更友好的 Markdown
- 需要加自定义 query 参数（例如城市、分页、筛选条件）
- 需要对错误做更细致提示

### 3.2 action 的两种写法
你可以在条目里写：

#### 写法 A：action 是字符串（推荐）
```qml
{
  name: "汇率",
  endpoint: "exchange-rate",
  icon: "💱",
  accent: "#F472B6",
  action: "getRate"
}
```

然后在 root（同一个 Rectangle）里实现：

```qml
function getRate(baseUrl, item, done, fail) { ... }
```

#### 写法 B：action 直接写函数
```qml
{
  name: "自定义功能",
  endpoint: "xxx",
  icon: "🧩",
  accent: "#A78BFA",
  action: function(baseUrl, item, done, fail) { ... }
}
```

> 但 QML 内联函数会让 `menuItems` 更长、不易维护；一般建议用字符串指向 root 上的函数。

---

## 4. action 函数签名与契约（必须遵守）

当条目存在 `action` 时，框架会把请求“完全交给你”，调用：

```js
fn(baseUrl, selectedItem, done, fail)
```

各参数含义：

- `baseUrl`：**不带任何参数**的基础地址  
  等于：`apiBaseUrl + apiPrefix + "/" + endpoint`

  例：`https://60s.mizhoubaobei.top/v2/exchange-rate`

- `item`：当前条目对象（含 name/endpoint/icon/accent/...）
- `done(mdString)`：成功回调  
  - 你必须传入 **Markdown 字符串**
  - 成功后页面会切到 `content` 并展示
- `fail(msg)`：失败回调  
  - 会设置 `errorMessage`
  - 并通过 `root.showErrorPopup(msg)` 弹窗提示

### 4.1 同步返回值（可选）
action 也支持**同步直接 return 字符串**：

```js
function myAction(baseUrl, item, done, fail) {
  return "# 标题\n\n内容"
}
```

框架检测到返回值是 string，会自动 `done(ret)`。

### 4.2 内容长度限制
无论默认模式还是 action 模式，都受：

```qml
property int maxContentLength: 1000000
```

超出会报 “内容过大，无法显示”。

---

### 5.1 示例 在 menuItems 里加条目
```qml
{
  name: "汇率",
  endpoint: "exchange-rate",
  icon: "💱",
  accent: "#F472B6",
  action: "getRate"
},
```

### 5.2 在 root 中实现函数
```qml
function getRate(baseUrl, item, done, fail) {
    // 1) 组装 URL
    var url = baseUrl + "?encoding=json"
    if (root.enableCacheBuster)
        url += "&" + root.cacheBusterKey + "=" + Date.now()

    // 2) 请求
    var x = new XMLHttpRequest()
    x.onreadystatechange = function() {
        if (x.readyState !== XMLHttpRequest.DONE) return

        if (x.status !== 200) {
            fail("自定义请求失败: HTTP " + x.status)
            return
        }

        // 3) 解析 JSON
        var jsonData = null
        try {
            jsonData = JSON.parse(x.responseText || "{}")
        } catch (e) {
            fail("JSON 解析失败: " + e)
            return
        }

        // 4) 解析逻辑
        function getRateText(jsonData) {
            var updatedDate = jsonData && jsonData.data ? jsonData.data.updated : ""
            var rates = (jsonData && jsonData.data && jsonData.data.rates) ? jsonData.data.rates : []

            var targetCurrencies = ["GBP", "JPY", "HKD", "USD", "EUR"]
            var targetRates = rates.filter(function(rate) {
                return targetCurrencies.indexOf(rate.currency) !== -1
            })

            var outputText = "日期：" + updatedDate + "\n\n"

            var cnyRate = rates.find(function(rate) { return rate.currency === "CNY" })
            if (cnyRate) {
                targetRates.forEach(function(rate) {
                    outputText += "- CNY -> " + rate.currency + "：**" + rate.rate + "**\n"
                })
            } else {
                return "错误：未找到 CNY 汇率"
            }

            return outputText
        }

        // 5) 生成 Markdown
        var bodyMd = getRateText(jsonData)
        var md = "# " + (item.name || "汇率") + "\n\n" + bodyMd

        done(md)
    }

    x.onerror = function() {
        fail("自定义请求网络错误")
    }

    x.open("GET", url)
    x.send()
}
```

---

## 6. 参数与缓存策略建议

### 6.1 全局服务端配置
已经提供了可配置项：

- `apiBaseUrl`：例如 `https://60s.mizhoubaobei.top`（建议自建API）
- `apiPrefix`：例如 `/v2`（通常不需要修改）

### 6.2 防缓存（推荐保留）
默认请求与自定义请求都可以加：

- `enableCacheBuster: true`
- `cacheBusterKey: "_t"`

这样每次都会带时间戳参数，避免 Qt/XHR 缓存导致内容不更新。