<p align="center">
  <img src="assets/readme/app-icon.png" width="96" alt="Panino Launcher icon">
</p>

# Panino Launcher

<p align="center">
  <a href="README.md">中文</a> | English | <a href="README.it.md">Italiano</a>
</p>

> [!WARNING]
> **关于 AI 辅助开发的赛博判决书 / The AI Verdict**
>
> 叮咚！听好了，各位代码纯洁圣母和键盘判官：本项目确实疯狂摄入了 AI 科技工业糖精，不过别慌，核心架构和代码已经由本大人亲自拿皮鞭 Review 并调教测试完毕。
> 别急着破防，你行你来同时把 **Haskell (硬核函数式 FP)** 和 **Swift (花心面向对象 OOP)** 强行塞进一个解耦架构里？在两个完全极端的脑回路之间疯狂来回劈叉，那酸爽的心智负担让人欲罢不能。在这种高强度的精神污染下，靠 AI 拯救我濒临坏掉的脑细胞，属于完全合法的紧急避险！
> 如果您对 AI 极度过敏，或者自我膨胀到想来对老子指点江山——那么这位*坚持古法纯手工敲打无添加老代码的大神*，右上角点叉，您己开个仓库从零手敲去吧。祝您早日用指甲盖在远古打孔纸带上抠出属于你的传世经典。**别下载，也别来 Issue 区展示你贫瘠的脑容量。** 本开源项目纯属个人无偿奉献，爱用不用，别指望我给你们提供什么好脸色，Roll（滚）！



Panino is a Minecraft Java Edition launcher exclusively for macOS, featuring multi-language support (currently supporting Simplified Chinese, English, French, Italian, and Spanish).

Built with a SwiftUI + Haskell Core architecture.

It is still community Alpha, not a finished product. It will make mistakes, expose unfinished edges, and still feel young in many places. But at least it is no longer just a UI shell: Core can install the game, schedule downloads, handle loaders, record tasks, run diagnostics, and start answering a more specific question:

> If Minecraft has to run on an M-series Mac, can the launcher do more than offer a few default arguments?

<p align="center">
  <img src="assets/readme/launch-light.png" alt="Panino Launcher launch dashboard">
</p>

## What Is It?

Panino has a simple skeleton:

```text
SwiftUI macOS App
  -> starts local panino-core
  -> localhost REST/SSE API
  -> Haskell Core installs, downloads, verifies, diagnoses, and generates launch arguments
  -> SwiftUI subscribes to task events and returns state to the user
```

I do not really want the UI to run while carrying all the complexity. The hard parts of a Minecraft launcher are often lower down: upstream metadata changes, a loader installer does not explain why it failed, one mod dependency only works on one version, the Java version and system architecture do not match, or a download source suddenly becomes slow this afternoon. Panino Core exists exactly for this dirty work.

## What It Can Already Do

- Start a local Haskell Core and protect the localhost API with a bearer token.
- Install Vanilla Minecraft, downloading and verifying client, libraries, assets, and natives.
- Install Fabric, Quilt, Forge, and NeoForge, while building an automatic resolution path for shader loaders such as Iris/Oculus.
- Record local instance state with isolated instance directories and `.panino/instance.json`.
- Search Modrinth / CurseForge content and parse project, version, file, and dependency models.
- Maintain task state, task history, and SSE event streams.
- Scan and check Java, while advancing managed runtime install/select/verify flows.
- Handle download scheduling, source probe, multipart, network diagnostics, and throughput records.
- Start building Apple Silicon tuning, JVM tuning, graphics tuning, performance evidence, typed install plan, and lockfile.

## What Is Not Done Well Yet

- Stable user-facing packages, Developer ID signing, notarization, and automatic updates have not reached stable release quality yet.
- The `.mrpack` / CurseForge zip import/export loop still needs more work.
- Mod updates, conflict resolution, crash-log analysis, and repair suggestions are still not mature enough.
- Microsoft login already has an implementation base, but release-grade tests, logout/revoke, and error recovery still need to be filled in.
- Diagnostic export needs a stricter unified redaction policy.
- Apple Silicon tuning must speak through real devices, real modpacks, and rollback evidence. It cannot rely only on nice-looking defaults.

## Screenshots

<table>
  <tr>
    <td><img src="assets/readme/discover-install.png" alt="Content install detail"></td>
    <td><img src="assets/readme/launch-dark.png" alt="Dark launch dashboard"></td>
  </tr>
  <tr>
    <td><sub>Online content, version matching, and install targets.</sub></td>
    <td><sub>Launch page and Pack Doctor state under different themes.</sub></td>
  </tr>
  <tr>
    <td><img src="assets/readme/instances-library.png" alt="Local instances library"></td>
    <td><img src="assets/readme/task-center.png" alt="Task center"></td>
  </tr>
  <tr>
    <td><sub>Local instance library. Every instance should have its own boundary.</sub></td>
    <td><sub>Task center. Failures and completions should not disappear quietly.</sub></td>
  </tr>
  <tr>
    <td colspan="2"><img src="assets/readme/download-settings.png" alt="Download settings"></td>
  </tr>
  <tr>
    <td colspan="2"><sub>Download sources, proxy, concurrency, and Core network strategy.</sub></td>
  </tr>
</table>

## Good Places To Contribute

If you only want to look at a finished launcher, it may still be early here. If you are willing to take a launcher apart and watch how it slowly becomes reliable software, there are still many empty seats.

- Haskell Core: dependency resolution, lockfile solver, typed install plan, structured diagnostics, property tests.
- SwiftUI macOS: native interaction, instance management, diagnostic visualization, settings page, task center, accessibility, and localization.
- Minecraft ecosystem: loader installation, modpack import/export, Modrinth / CurseForge compatibility, crash logs, and dependency conflict analysis.
- Apple Silicon: JVM arguments, graphics settings, performance sampling, rollback strategy, and real modpack validation.
- Release engineering: signing, notarization, automatic updates, privacy audit, diagnostic package redaction, and community beta flow.

Very welcome! 🎉

## Build

Requires macOS 14+, Swift 6 toolchain / Xcode, GHC, Cabal, and Java 17 or Java 21 for running Minecraft.

From the repository root:

```sh
./scripts/test-core.sh
./scripts/build-core.sh
./scripts/build-swift.sh
./scripts/smoke-test.sh
git diff --check
```

Network and download verification:

```sh
./scripts/benchmark-core-network.sh
./scripts/verify-core-network-matrix.sh
```

If your network environment needs a proxy:

```sh
https_proxy=http://127.0.0.1:7890 \
http_proxy=http://127.0.0.1:7890 \
all_proxy=socks5://127.0.0.1:7891 \
./scripts/test-core.sh
```

Core CLI:

```sh
cd core
cabal run panino-core -- --version
cabal run panino-core -- health
cabal run panino-core -- install --version 1.20.1 --game-dir /tmp/panino-minecraft --concurrency 16
cabal run panino-core -- serve --host 127.0.0.1 --port 8080 --session-token dev-token
```

macOS App:

```sh
cd macos/PaninoLauncher
swift build
swift run PaninoLauncher
```

## Repository Structure

```text
core/                         Haskell panino-core: API, install, download, diagnostics, launch core
macos/PaninoLauncher/         SwiftUI macOS app: UI, state, Core process, API client
companion/                    Optional in-game companion direction
scripts/                      Build, test, smoke, and network verification scripts
docs/                         Project map, development checklists, competitive analysis, release-trust checklist
assets/readme/                README screenshots
LICENSE                       Apache-2.0 license text
NOTICE.md                     Attribution, naming, and trademark boundary notice
```

## Development Notes

- Core binds to `127.0.0.1` by default, and the API requires a bearer token.
- Swift manages the Core lifecycle through `CoreProcessManager`.
- Sensitive information such as Microsoft refresh tokens and CurseForge API keys should go into Keychain.
- Before publishing issues, logs, or diagnostic packages, confirm that there is no `access_token`, `refresh_token`, `api_key`, `Authorization`, `--session-token`, or `/Users/<name>/`.
- Core API changes usually need to sync Haskell API types, routes, Swift `LauncherApiClient`, `CoreModels`, and related Store/UI.

## License And Attribution

This project is open-sourced under the Apache License 2.0. You may use, modify, and distribute the code, but you must comply with `LICENSE` and `NOTICE.md`.

Core requirements:

1. Preserve the Panino attribution notice in `NOTICE.md`.
2. Modified and redistributed derivative versions must use a different project name and logo.
3. Do not make users believe that a derivative version is the official Panino release.

Apache-2.0 does not grant permission to use the Panino name, logo, or other project identity marks as trademarks. Naming and logo boundaries are defined by `NOTICE.md`.

