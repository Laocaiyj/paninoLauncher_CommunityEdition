<p align="center">
  <img src="assets/readme/app-icon.png" width="96" alt="Panino Launcher icon">
</p>

# Panino Launcher

<p align="center">
  中文 | <a href="README.en.md">English</a> | <a href="README.it.md">Italiano</a>
</p>

> [!WARNING]
> **关于 AI 辅助开发的赛博判决书 / The AI Verdict**
>
> 叮咚！听好了，各位代码纯洁圣母和键盘判官：本项目确实疯狂摄入了 AI 科技工业糖精，不过别慌，核心架构和代码已经由本大人亲自拿皮鞭 Review 并调教测试完毕。
> 别急着破防，你行你来同时把 **Haskell (硬核函数式 FP)** 和 **Swift (花心面向对象 OOP)** 强行塞进一个解耦架构里？在两个完全极端的脑回路之间疯狂来回劈叉，那酸爽的心智负担让人欲罢不能。在这种高强度的精神污染下，靠 AI 拯救我濒临坏掉的脑细胞，属于完全合法的紧急避险！
> 如果您对 AI 极度过敏，或者自我膨胀到想来对老子指点江山——那么这位*坚持古法纯手工敲打无添加老代码的大神*，右上角点叉，您己开个仓库从零手敲去吧。祝您早日用指甲盖在远古打孔纸带上抠出属于你的传世经典。**别下载，也别来 Issue 区展示你贫瘠的脑容量。** 本开源项目纯属个人无偿奉献，爱用不用，别指望我给你们提供什么好脸色，Roll（滚）！



Panino 是一个只面向 macOS 的 Minecraft Java Edition 启动器，支持多自然语言 [目前支持 简体中文、英文、法语、意大利语、西班牙语]。

使用SwiftUI + Haskell Core 架构

它现在还是社区 Alpha，非完成品。它会犯错，会暴露出尚未处理好的边界，也还有许多地方显得年轻。但至少它已经不只是一个界面壳子了：Core 会安装游戏、调度下载、处理 loader、记录任务、做诊断，并且开始尝试回答一个更具体的问题：

> 如果 Minecraft 必须跑在一台 M 系列 Mac 上，启动器能不能比给几组默认参数多做一点事？

<p align="center">
  <img src="assets/readme/launch-light.png" alt="Panino Launcher launch dashboard">
</p>

## 是什么？

Panino 的骨架很简单：

```text
SwiftUI macOS App
  -> 启动本地 panino-core
  -> localhost REST/SSE API
  -> Haskell Core 安装、下载、校验、诊断、生成启动参数
  -> SwiftUI 订阅任务事件，把状态还给用户
```

我不太想让 UI 背着所有复杂性运行。Minecraft 启动器真正难的部分，往往藏在更低的地方：上游元数据变了、loader installer 没说清楚为什么失败、某个 mod 依赖只在某个版本下可用、Java 版本和系统架构不合适、下载源在今天下午忽然变慢。Panino 的 Core 正是为了这些脏活存在。

## 现在已经能做的事

- 启动一个本地 Haskell Core，并通过 bearer token 保护 localhost API。
- 安装 Vanilla Minecraft，下载并校验 client、libraries、assets 和 natives。
- 安装 Fabric、Quilt、Forge、NeoForge，并为 Iris/Oculus 这类光影加载器建立自动解析路径。
- 用隔离实例目录和 `.panino/instance.json` 记录本地实例状态。
- 搜索 Modrinth / CurseForge 内容，解析项目、版本、文件和依赖模型。
- 维护任务状态、任务历史和 SSE 事件流。
- 扫描和检查 Java，并推进托管 runtime 的安装/选择/校验。
- 做下载调度、source probe、multipart、网络诊断和吞吐记录。
- 开始建设 Apple Silicon 调校、JVM tuning、graphics tuning、性能证据链、typed install plan 和 lockfile。

## 还没做好的地方

- 正式安装包、开发者签名、公证和自动更新还没有达到稳定发布标准。
- `.mrpack` / CurseForge zip 的导入导出闭环还需要继续打磨。
- mod 更新、冲突解决、崩溃日志分析和修复建议仍然不够成熟。
- Microsoft 登录已经有实现基础，但发布级测试、登出/撤销和错误恢复还要补。
- 诊断导出需要更严格的统一脱敏策略。
- Apple Silicon 调校必须靠真实设备、真实整合包和可回滚证据说话，并不能只靠漂亮的默认值。

## 一些截图

<table>
  <tr>
    <td><img src="assets/readme/discover-install.png" alt="Content install detail"></td>
    <td><img src="assets/readme/launch-dark.png" alt="Dark launch dashboard"></td>
  </tr>
  <tr>
    <td><sub>在线内容、版本匹配和安装目标。</sub></td>
    <td><sub>不同主题下的启动页和 Pack Doctor 状态。</sub></td>
  </tr>
  <tr>
    <td><img src="assets/readme/instances-library.png" alt="Local instances library"></td>
    <td><img src="assets/readme/task-center.png" alt="Task center"></td>
  </tr>
  <tr>
    <td><sub>本地实例库。每个实例都应当有自己的边界。</sub></td>
    <td><sub>任务中心。失败和完成都不该静悄悄地消失。</sub></td>
  </tr>
  <tr>
    <td colspan="2"><img src="assets/readme/download-settings.png" alt="Download settings"></td>
  </tr>
  <tr>
    <td colspan="2"><sub>下载源、代理、并发和 Core 网络策略。</sub></td>
  </tr>
</table>

## 适合贡献的方向

如果你只是想看一个成品启动器，这里可能还早。如果你愿意把一个启动器拆开，看看它如何慢慢变成可靠的软件，这里正好还有很多位置空着。

- Haskell Core：依赖解析、lockfile solver、typed install plan、structured diagnostics、property tests。
- SwiftUI macOS：原生交互、实例管理、诊断可视化、设置页、任务中心、可访问性和本地化。
- Minecraft 生态：loader 安装、modpack 导入导出、Modrinth / CurseForge 兼容、崩溃日志和依赖冲突分析。
- Apple Silicon：JVM 参数、图形设置、性能采样、回滚策略和真实整合包验证。
- 发布工程：签名、公证、自动更新、隐私审计、诊断包脱敏和社区 beta 流程。

非常欢迎！🎉

## 构建

需要 macOS 14+、Swift 6 toolchain / Xcode、GHC、Cabal，以及用于运行 Minecraft 的 Java 17 或 Java 21。

从仓库根目录：

```sh
./scripts/test-core.sh
./scripts/build-core.sh
./scripts/build-swift.sh
./scripts/smoke-test.sh
git diff --check
```

网络和下载验证：

```sh
./scripts/benchmark-core-network.sh
./scripts/verify-core-network-matrix.sh
```

如果网络环境需要代理：

```sh
https_proxy=http://127.0.0.1:7890 \
http_proxy=http://127.0.0.1:7890 \
all_proxy=socks5://127.0.0.1:7891 \
./scripts/test-core.sh
```

Core CLI：

```sh
cd core
cabal run panino-core -- --version
cabal run panino-core -- health
cabal run panino-core -- install --version 1.20.1 --game-dir /tmp/panino-minecraft --concurrency 16
cabal run panino-core -- serve --host 127.0.0.1 --port 8080 --session-token dev-token
```

macOS App：

```sh
cd macos/PaninoLauncher
swift build
swift run PaninoLauncher
```

## 仓库结构

```text
core/                         Haskell panino-core：API、安装、下载、诊断、启动核心
macos/PaninoLauncher/         SwiftUI macOS app：界面、状态、Core 进程和 API 客户端
companion/                    可选的游戏内 companion 方向代码
scripts/                      构建、测试、smoke、网络验证脚本
docs/                         项目地图、开发清单、竞品分析和发布信任清单
assets/readme/                README 展示图
LICENSE                       Apache-2.0 协议文本
NOTICE.md                     署名、名称和商标边界说明
```

## 开发时请留意

- Core 默认只绑定 `127.0.0.1`，API 需要 bearer token。
- Swift 侧通过 `CoreProcessManager` 管理 Core 生命周期。
- Microsoft refresh token、CurseForge API key 等敏感信息应进入 Keychain。
- 公开 issue、日志或诊断包前，请确认没有 `access_token`、`refresh_token`, `api_key`, `Authorization`, `--session-token` 或 `/Users/<name>/`。
- 变更 Core API 时，通常需要同步 Haskell API 类型、路由、Swift `LauncherApiClient`、`CoreModels` 和相关 Store/UI。

## 协议与署名

本项目代码基于 Apache License 2.0 开源。您可以使用、修改和分发代码，但需要遵守 `LICENSE` 和 `NOTICE.md`。

核心要求：

1. 保留 `NOTICE.md` 中的 Panino 署名信息。
2. 修改并重新发布的衍生版本必须更换项目名称和 Logo。
3. 不得让用户误以为衍生版本是 Panino 官方原版。

Apache-2.0 不授予 Panino 名称、Logo 或其他项目标识的商标使用权。名称与 Logo 的边界以 `NOTICE.md` 为准。
