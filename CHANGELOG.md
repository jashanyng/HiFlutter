# 变更日志（Changelog）

本文件是 HiFlutter 全仓版本更新说明的**唯一事实源（Single Source of Truth）**，统一以简体中文记录各版本的整体演进、新增能力、修复与迁移要点。

> 各独立子包目录下的英文 `packages/*/CHANGELOG.md` 仍同步保留并用于 pub.dev 发布展示；日常开发与消费项目升级请以本文件及 [兼容性与升级指南](docs/compatibility.md) 为准。执行 `dart run tool/bump_version.dart <version>` 时会自动将下方 `## [Unreleased]` 归档为 `## [<version>] - YYYY-MM-DD` 并在顶部保留 `## [Unreleased]`。

## [Unreleased]

## [0.0.1]

HiFlutter 制作期初始基线，确立 Dart pub workspace 多包架构（20 个可发布包共享统一裸版本 `0.0.1`，另含不发布的本地示例 App `apps/showcase`）与全量 8 阶段门禁工具链（`tool/check.dart`）：

- **基础契约与可观测性（`base` 家族）**：
  - `hiflutter_base`：密封 `HiError` 分层错误模型、`HiConvert` 宽松类型转换、`HiMapPick` 多候选键读取、多路由不可绕过脱敏日志 `HiLogger`/`HiLog` 与 `HiConsoleLogSink`，以及受 `HiConsent` 隐私同意门控约束的 `HiAnalytics`、`HiCrashReporter` 契约。
  - `hiflutter_base_log_file`：基于 `path_provider` 的按天轮转、单文件上限切分与过期清理的日志文件输出端 `HiFileLogSink`。
- **核心工具与设备能力（`core` 家族）**：
  - `hiflutter_core`：`HiErrorCapture` 全局错误接管与守护 Zone、`HiSafeValueNotifier`、`HiFormat`（数值、紧凑计数与文件大小格式化）、`HiLinkDetector`、`HiColor` 及其上下文扩展、`HiDeviceInfoSource` 契约与 `HiStaticDeviceInfoSource`。
  - `hiflutter_core_device`：基于 `device_info_plus` 与 `package_info_plus` 实现 `HiPlatformDeviceInfoSource`。
- **网络传输与连通性（`net` 家族）**：
  - `hiflutter_net`：`HiHttpClient`、`HiTransport` 契约与 `HiMemoryTransport`、`HiRequest`/`HiResponse`、`HiCancelToken`、`HiHttpInterceptor` 拦截器链、`HiEnvelope`/`HiReply` 统一解包、`HiPageResult` 及 `HiConnectivity` 契约。
  - `hiflutter_net_dio`：基于 `dio` 的纯 Dart 传输适配 `HiDioTransport`（异常归一化为 `HiError`，零第三方类型外露），并提供测试注入入口 `package:hiflutter_net_dio/testing.dart`。
  - `hiflutter_net_connectivity`（可选适配包）：基于 `connectivity_plus` 实现网络状态流监听 `HiPlusConnectivity`。
- **路由导航与外链（`nav` 家族）**：
  - `hiflutter_nav`：强类型 `HiRoute`/`HiRouteParams`、`HiRouteTable`、`HiDeepLinkGuard` 白名单守卫以及 `HiNavigator`、`HiPage`、`HiLinkOpener` 契约。
  - `hiflutter_nav_go_router`：基于 `go_router` 从 `HiRouteTable` 生成声明式路由的 `HiGoRouterNavigator`。
  - `hiflutter_nav_url_launcher`：基于 `url_launcher` 的外链打开适配 `HiUrlLauncherLinkOpener`。
- **持久化存储（`store` 家族）**：
  - `hiflutter_store`：`HiKeyValueStore`（拒存凭据敏感键）、`HiSecureStore`、`HiFileStore`（防路径穿越校验）以及各自后端契约与内存实现。
  - `hiflutter_store_prefs`：基于 `shared_preferences`（`SharedPreferencesAsync`）的 `HiPrefsKeyValueBackend`。
  - `hiflutter_store_secure`：基于 `flutter_secure_storage` 的 `HiSecureStorageBackend`。
  - `hiflutter_store_file`：基于 `path_provider` 与 `dart:io` 的 `HiAppFileBackend`。
- **通用 UI 组件（`suite` 家族）**：
  - `hiflutter_suite`：基于 `material_ui` 与 `intl`（`gen-l10n`）构建的中英本地化组件体系，涵盖 `HiSuiteLocalizations`、`HiSuiteMetrics`、状态视图（`HiLoadingView`、`HiEmptyView`、`HiErrorView`、`HiStateView`）、`HiPaginationController`/`HiPaginatedListView`、`HiToast`、`HiConfirmDialog`、`HiListSection`/`HiListRow`/`HiSelectableListRow`、`HiPrimaryButton` 与 `HiSearchField`。
  - `hiflutter_suite_cached_image`（可选适配包）：基于 `cached_network_image` 的图片缓存与缩放预览组件 `HiCachedImage`、`HiImageViewer`。
  - `hiflutter_suite_webview`（可选适配包）：基于 `webview_flutter` 的网页容器 `HiWebViewPage`（含进度条、标题跟踪、返回历史与外链转交）。
- **状态管理骨架、伞包与 CLI 工具**：
  - `hiflutter_riverpod`（可选集成包）：提供 12 个契约 Provider、`HiPaginationNotifier`/`HiPaginationState` 与有序启动引导 `HiRiverpodBootstrap`。
  - `hiflutter`（伞包）：重新导出 14 个核心契约与默认非厂商适配包的自有公开 API，零第三方类型穿透且零自动初始化。
  - `hiflutter_tool`（CLI 工具）：提供 `hiflutter` 命令，支持在 `source`（源码模式）、`pin`（锁定模式）与 `hosted`（发布模式）间无侵入切换及 `hiflutter check [--release]` 门禁校验。
