# HiFlutter 兼容性、版本契约与升级迁移指南

本文件规定 HiFlutter 的运行环境与依赖兼容矩阵、三阶段演进兼容契约，以及消费项目在不同集成模式下的升级与迁移操作指引。

## 环境与依赖兼容矩阵

| 维度 | 当前基线要求 | 说明与门禁约束 |
| --- | --- | --- |
| **Dart SDK** | `^3.14.0` | 全工作区统一约束，支持 workspace 分辨率与现代 Dart 语法特性 |
| **Flutter SDK** | `>=3.50.0` | 全部 Flutter 契约包、适配包与示例 App 共同基线 |
| **一等支持平台** | Android、iOS | 新增库与原生桥接须优先验证 Android 与 iOS 构建通过（`dart run tool/check.dart --build`） |
| **Flutter UI 导入边界** | `package:flutter/widgets.dart` + `package:material_ui/material_ui.dart` | 适配 Flutter 3.50+ 剥离 Material 组件的架构；工作区全面禁止直接导入或导出 `package:flutter/material.dart`（由 `DepsStage` 自动拦截） |
| **第三方依赖策略** | 一律使用 caret（`^x.y.z`）约束 | 完整版本基线与破坏性更新（`deps-breaking`）评估流程见 [第三方依赖准入与版本基线](engineering/dependencies.md) |

- **契约包零第三方依赖边界**：`hiflutter_base`、`hiflutter_core`、`hiflutter_net`、`hiflutter_nav`、`hiflutter_store` 仅可依赖 Dart 官方 `meta`、`collection` 与（Flutter 契约包所需的）Flutter SDK；`hiflutter_suite` 特批允许 `intl`、`flutter_localizations` 与 `material_ui`。
- **第三方类型隔离**：第三方库与原生插件的类型及异常禁止穿透契约包公开接口、伞包 `hiflutter` 导出面或普通适配包公开入口。

## 演进阶段与版本兼容契约

### 全仓单版本与裸格式

- 全部 **20 个可发布包**始终共享同一不带 `v` 前缀、无预发布或构建后缀的**裸 `x.y.z`** 版本号（当前基线为 `0.0.1`），Git 发版标签同用裸 `x.y.z`；包间内部依赖统一声明为 `^<当前版本>`。
- 仅维护者有权决定切换演进阶段、修改 `x`/`y`、在 `main` 打发版 tag 或向 pub.dev 发布；智能体日常仅可递增 `z`（`tool/bump_version.dart` 默认拦截未显式传入 `--allow-xy-bump` 的 `x`/`y` 变更）。

### 三阶段演进生命周期

| 演进阶段 | 当前状态 | 包结构与职责 | 公开接口向后兼容性 | 交付与发版节奏 |
| --- | --- | --- | --- | --- |
| **制作期** | **当前阶段**（`0.0.1`） | 允许调整顶层包家族、子包划分、职责归属与公开接口以完成产品化定型 | **不保留**向后兼容垫片或废弃别名；改动须同步更新根 `CHANGELOG.md` 及源码联调消费项目 | 日常在开发分支演进，不打 Git 标签、不向 pub.dev 发布 |
| **改进完善期** | 未进入 | 顶层包家族、子包划分与整体组织方式**严格保持不变**，仅在既有边界内扩充完善 | 仍**无需保留**代码向后兼容，可优化已有接口签名 | 仅在维护者明确确认后切入 |
| **维护期** | 未进入 | 包结构严格冻结 | **严格遵守**代码向后兼容；新增功能诉求须先输出可行性与必要性评估报告并获维护者同意 | 仅做平台/SDK 新特性适配与缺陷修复 |

### `1.0.0` 首发与后续批次、热修语义

- **制作期与 `1.0.0` 首发**：制作期从 `0.0.1` 起步并仅递增 `z`；首次正式对外发布（上传 pub.dev，或首个消费项目提审上架需锁定正式发版制品）时由维护者决定定为 `1.0.0`。
- **`1.0.0` 后批次演进语义**：
  - `x`：重大架构调整、包组织重构或品牌代际；
  - `y`：开发期项目周期批次——当同批次某个消费项目提审上架、锁定发版 `x.y.z` 后，其余仍在源码开发的消费项目立即切入 `x.(y+1).0` 继续演进，原 `x.y.*` 留作该已上架消费项目的独立紧急热修通道；
  - `z`：同批次内的常规功能递增与缺陷修复。
- **维护分支热修**：仅当已发版/已上架消费项目遇阻塞性问题且升级到当前 `dev`/`main` 批次代价过大时，由维护者从锁定 tag（如 `1.0.0`）切出 `maint/1.0` 分支合入最小修复并递增 `z`（如 `1.0.1`），详见 [发版与维护分支规范](engineering/release.md)。

## 升级与迁移指南

消费项目自身 `pubspec.yaml` 中仅声明常规版本依赖（如 `hiflutter: ^0.0.1`），不直接写入 `path:` 或 `git:`，统一通过 `hiflutter` CLI 管理 `pubspec_overrides.yaml`（原理见 [消费项目集成模式与接入规则](engineering/integration.md)）。

### 1. 三种集成模式切换与升级步骤

#### 源码模式（`hiflutter mode source`）

适用于正在与同级 `../HiFlutter` 仓库同步开发联调的消费项目：

```bash
# 在消费项目根目录执行
hiflutter mode source
flutter pub get
hiflutter check
```

- 升级方式：拉取 `HiFlutter` 目标分支最新代码后，在消费项目重新运行 `flutter pub get`（若 HiFlutter 新增或调整了传递依赖包，先重新执行一次 `hiflutter mode source` 刷新覆盖闭包）。
- 发布门禁：源码模式下执行 `hiflutter check --release` 会以退出码 `1` 拦截，禁止带源码路径覆盖打包分发。

#### 锁定模式（`hiflutter mode pin <tag>`）

适用于 HiFlutter 尚未发布至 pub.dev 期间需要冻结可复现版本的测试/发布构建：

```bash
# 切换或升级到指定裸发版标签（如 0.0.1、1.0.0）
hiflutter mode pin <tag>
flutter pub get
hiflutter check --release
```

- 升级步骤：
  1. 先查阅根目录 [CHANGELOG.md](../CHANGELOG.md) 目标版本区间的变更与迁移说明，确认消费项目需适配的 API 变更；
  2. 若版本跨度超出原有 `pubspec.yaml` caret 约束（如 `^0.0.1` 升级到 `1.0.0`），同步更新消费项目 `pubspec.yaml` 依赖约束；
  3. 执行 `hiflutter mode pin <tag> && flutter pub get && hiflutter check --release` 验证 `pubspec.lock` 的 `resolved-ref` 与目标 tag 一致，并将 `pubspec_overrides.yaml` 与 `pubspec.lock` 一并提交。

#### 发布模式（`hiflutter mode hosted`）

适用于 HiFlutter 正式对外发布到 pub.dev 之后：

```bash
# 清除 tool 托管的覆盖区块，回退到 pub.dev 解析
hiflutter mode hosted
flutter pub get
hiflutter check --release
```

- 升级步骤：对照根目录 [CHANGELOG.md](../CHANGELOG.md) 评估目标版本影响，按需更新消费项目 `pubspec.yaml` 约束后执行 `flutter pub upgrade` 与 `hiflutter check --release`。

### 2. 跨版本破坏性变更与迁移记录

> 每次版本升级若引入 API 签名变更、包拆分/迁移或行为语义调整，除记录在根目录 `CHANGELOG.md` 对应版本小节外，涉及跨版本迁移路径时须同步补充下表。

| 版本区间 | 变更性质 | 影响范围 | 迁移步骤与适配说明 |
| --- | --- | --- | --- |
| `0.0.1`（当前基线） | 初始基线 | 全部 20 个可发布包 | 初始定型基线，无前置版本迁移要求 |
