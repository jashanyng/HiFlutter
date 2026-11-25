# AGENTS.md

本文件是在 HiFlutter 仓库中工作的智能体（Claude Code、Codex 等）的项目级规则入口。`CLAUDE.md` 通过 `@AGENTS.md` 引入本文件。

## 语言约定

- 项目级智能体规则、领域与协作/工程文档（`AGENTS.md`、`README.md`、`docs/**/*.md`、`GLOSSARY.md`、Issue / PR / Spec 正文与评论等）一律使用简体中文撰写；命令、路径、代码标识符、仓库名与固定标签名（如 `needs-triage`、`deps-breaking`）保持原样。
- 各独立包内的 `packages/*/README.md`、`packages/*/CHANGELOG.md`、dartdoc 注释与 Git 提交信息使用英文。
- 领域术语以根目录 [GLOSSARY.md](GLOSSARY.md) 为准，不使用其中明确避免的同义词。

## 硬边界

1. **业务无关**：HiFlutter 仅提供通用基础设施，禁止任何消费产品名或特定业务概念进入代码、路径或文档；受 `tool/business_terms.txt` 与 `TermsStage` 强制扫描拦截。
2. **契约包零第三方依赖**：契约包仅可依赖 Dart 官方 `meta`、`collection`（Flutter 契约包可依赖 Flutter SDK，`hiflutter_suite` 例外允许 `intl`、`flutter_localizations` 与 `material_ui`）；第三方实现与厂商 SDK 一律放入独立适配包。
3. **第三方类型不穿透**：第三方库或插件的类型与异常不得出现在契约包公开接口、伞包导出面或未标明测试用途的适配包公开入口中。
4. **严格依赖方向与无环**：包间依赖必须符合 `tool/src/package_rules.dart` 允许表且禁止成环，新增或调整包依赖前必须先核对规则表。详见 `docs/architecture/packages.md`。
5. **禁止全局可变单例（日志除外）**：能力一律通过构造器注入或 `hiflutter_riverpod` 组合根覆盖提供；仅 `HiLog.install` 允许作为一次性的全局日志入口（ADR-0005），安装后不可替换。
6. **使用 `widgets.dart` 与 `material_ui`**：Flutter 代码导入 `package:flutter/widgets.dart`，Material 3 组件导入 `package:material_ui/material_ui.dart`；工作区全成员的 `package:flutter/material.dart` 导入/导出已由 `dart run tool/check.dart` 的 `deps` 阶段（`DepsStage`）自动拦截，细则见 `docs/engineering/coding.md`。
7. **厂商 SDK 不预建**：友盟、Firebase、Sentry、EMAS 等商业厂商 SDK 暂不预建适配包，待具体消费项目需要时再新增独立适配包。
8. **伞包不初始化**：伞包 `hiflutter` 只重新导出核心契约与默认非厂商适配包的自有公开 API，不得导出第三方类型或触发任何自动初始化。
9. **遵循当前演进阶段与升版边界**：包结构调整范围、公开接口向后兼容性及通用能力沉淀边界严格遵守下方 [演进阶段与版本治理](#演进阶段与版本治理)（当前处于**制作期**）；任何版本更新仅允许递增 `z`，修改 `x` 或 `y` 必须获维护者明确同意。
10. **发版与发布由维护者决定**：修改代码、合并 `dev` 不得擅自修改 `main` 分支、打任何 Git 标签、或运行真实 `pub publish`；发版（在 `main` 打裸 `x.y.z` 标签）与发布（上传 pub.dev）相互独立，仅在维护者明确要求时执行。详见下方 [演进阶段与版本治理](#演进阶段与版本治理) 与 `docs/engineering/release.md`。

## 演进阶段与版本治理

### 三阶段演进生命周期（当前阶段：制作期）

- **制作期（当前阶段）**：面向产品化定型的打磨阶段。消费项目开发过程中，主动将剥离业务语义后可供多数同平台消费项目复用的通用基础设施与组件沉淀回 HiFlutter；允许为产品化定型调整顶层包家族、子包划分、职责归属与公开接口，不保留向后兼容垫片或废弃别名（发生破坏性调整时直接同步更新相关包、`CHANGELOG.md` 迁移要点及源码联调的消费项目）。制作期日常提交在分支演进，不打 Git 标签、不向 pub.dev 发布。
- **改进完善期**：顶层包家族、子包划分与整体组织方式严格保持不变；仅在既有职责边界内扩充、改进和完善能力与公开接口品质，仍无需保留代码向后兼容。
- **维护期**：包结构严格冻结并遵守代码向后兼容，日常仅聚焦平台/SDK 新特性适配与缺陷修复；当确有新增功能诉求时，必须先输出可行性与必要性验证评估报告并获维护者明确同意后才可实施。
- **阶段切换权**：演进阶段的切换权完全由维护者按实际成熟度独立决定并显式授权更新；严禁智能体在任务现场自行推定或切换阶段（智能体仅可在观察到成熟信号时给出提醒建议）。
- **与消费项目集成模式门禁的正交关系**：本库的三阶段演进生命周期管辖库结构可变性、公开接口兼容性与能力沉淀准入；消费项目的集成模式门禁（开发期源码模式 / 未上 pub.dev 发布期锁定模式 / 正式上架 pub.dev 后发布模式，`hiflutter check --release` 阻断源码模式）管辖消费项目接入形态，二者正交并存、互不替代。

### 裸 `x.y.z` 版本与标签规则

- **全仓单版本与裸格式**：全部 20 个可发布包共享同一版本号；所有版本号定义与 Git 标签一律采用**不带 `v` 前缀的裸 `x.y.z` 三段非负整数格式**（无 `v` 前缀、无预发布或构建后缀）。
- **制作期起步与 `1.0.0` 首发**：制作期统一从 `0.0.1` 起步并仅递增 `z`；首次正式对外发布（上传 pub.dev，或首个消费项目提审上架需锁定正式发版制品）时定为 `1.0.0`。
- **`1.0.0` 后批次演进语义**：`x` 代表重大架构、包组织或品牌代际；`y` 代表开发期项目周期批次（同批次某个消费项目提审上架时，将当前 `x.y.z` 发版/发布供其锁定，其余仍在源码开发的消费项目立即切入 `x.(y+1).0` 继续演进，原 `x.y.*` 留作已上架消费项目的独立紧急热修通道）；`z` 代表同批次功能与修复递增。
- **升版权限与工具门禁**：智能体在任何版本更新操作中**仅被允许递增 `z`**，任何对 `x` 或 `y` 的修改必须经维护者明确同意；统一改版工具 `dart run tool/bump_version.dart` 默认拒绝任何未显式传入 `--allow-xy-bump` 的 `x` 或 `y` 变更。

## 验证门禁

- 任何代码或文档改动完成后，提交前必须运行总检查并确认全部阶段通过：
  - 常规改动：`dart run tool/check.dart`
  - 涉及示例 App `apps/showcase` 原生构建或宿主配置：`dart run tool/check.dart --build`
- 新增与修改功能按 TDD 实施，公开 API 须有英文 dartdoc；成员包测试仅导入公开库入口（`deps` 阶段自动拦截直接导入 `src/`）。详见 `docs/engineering/coding.md`。

## 文档导航

需要深入某类上下文时按需读取对应文档（完整索引见 `docs/README.md`）：

- **调整包结构、新增包或改动依赖**：读 `docs/architecture/packages.md` 与 `docs/adr/0001`–`0004`
- **引入、升级或排查第三方依赖冲突/破坏性更新**：读 `docs/engineering/dependencies.md`
- **使用或维护消费项目集成模式与发布检查**：读 `docs/engineering/integration.md` 与 `docs/adr/0003-three-integration-modes.md`
- **执行统一版本升级、发版或维护分支**：读 `docs/engineering/release.md`
- **编写 Dart/Flutter 代码、异常、UI 组件或测试**：读 `docs/engineering/coding.md`
- **改动日志、脱敏、统计/崩溃上报或全局错误捕获**：读 `docs/engineering/observability.md` 与 `docs/adr/0005-global-log-entry-exception.md`

## Agent skills

### Issue tracker

Issue 与 Spec 存放在 GitHub 仓库 `jashanyng/HiFlutter` 的 Issues 中，通过 `gh` CLI 操作。详见 `docs/agents/issue-tracker.md`。

### Triage labels

使用默认的五个分诊标签：`needs-triage`、`needs-info`、`ready-for-agent`、`ready-for-human`、`wontfix`；另有工作流维护的非分诊标签 `deps-breaking`。详见 `docs/agents/triage-labels.md`。

### Domain docs

单上下文（single-context）布局：仓库根目录一个 `GLOSSARY.md`，架构决策记录放在 `docs/adr/`。详见 `docs/agents/domain.md`。
