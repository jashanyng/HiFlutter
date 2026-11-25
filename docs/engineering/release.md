# 版本号、发版、发布与维护分支规范

本文件定义 HiFlutter 多包仓库的版本号演进规则、统一改版工具以及“发版（Git tag）”与“发布（pub.dev）”分离的交付流程。

## 统一版本号规则

- **全仓单版本与裸格式**：HiFlutter 全部 20 个可发布包始终共享同一版本号；所有版本号定义与 Git 标签一律采用**不带 `v` 前缀的裸 `x.y.z` 三段非负整数格式**（无 `v` 前缀、无预发布或构建后缀）。包间依赖约束统一声明为 `^<当前版本>`，在仓库根 pub workspace 内本地解析。
- **不发布标识**：可发布包的 `pubspec.yaml` 不写 `publish_to: none`；仅仓库根 `pubspec.yaml`（`hiflutter_workspace`）与示例 App `apps/showcase/pubspec.yaml` 声明 `publish_to: none`。
- **三阶段演进生命周期**（当前处于**制作期**，阶段切换权完全归属维护者，严禁智能体自行推定或切换）：
  - **制作期（当前阶段）**：允许调整顶层包家族、子包划分、职责归属与公开接口以完成产品化定型，主动沉淀剥离业务语义后的通用基础设施与组件，不保留向后兼容垫片或废弃别名（同步更新相关包、`CHANGELOG.md` 迁移要点及源码联调的消费项目）；日常提交在分支演进，不打 Git 标签、不向 pub.dev 发布。
  - **改进完善期**：顶层包家族、子包划分与整体组织方式严格保持不变，仅在既有职责边界内扩充与完善能力及公开接口品质，仍无需保留代码向后兼容。
  - **维护期**：包结构严格冻结并遵守代码向后兼容，日常仅做平台/SDK 新特性适配与缺陷修复；新增功能诉求必须先输出可行性与必要性验证评估报告并获维护者明确同意后才可实施。
- **裸 `x.y.z` 版本演进与批次规则**：
  - **制作期起步与 `1.0.0` 首发**：制作期统一从 `0.0.1` 起步并仅递增 `z`；首次正式对外发布（上传 pub.dev，或首个消费项目提审上架需锁定正式发版制品）时定为 `1.0.0`。
  - **`1.0.0` 后批次演进语义**：`x` 代表重大架构、包组织或品牌代际；`y` 代表开发期项目周期批次（同批次某个消费项目提审上架时，将当前 `x.y.z` 发版/发布供其锁定，其余仍在源码开发的消费项目立即切入 `x.(y+1).0` 继续演进，原 `x.y.*` 留作已上架消费项目的独立紧急热修通道）；`z` 代表同批次功能与修复递增。
  - **升版权限**：智能体在任何版本更新操作中**仅被允许递增 `z`**，任何对 `x` 或 `y` 的修改必须经维护者明确同意。

## 统一升级版本号（`tool/bump_version.dart`）

禁止手工逐包修改版本号，统一使用仓库脚本：

```bash
dart run tool/bump_version.dart [--root <dir>] [--allow-xy-bump] <version>
```

脚本行为说明（见 `tool/src/bump_version.dart`）：

1. 校验 `<version>` 必须是不带 `v` 前缀的裸 `x.y.z` 三段非负整数格式，且严格大于当前全部可发布包版本；格式或参数错误返回 `64`，版本未前进返回 `1`。
2. 默认仅允许保持 `x`、`y` 不变并递增 `z`；修改 `x` 或 `y` 须经维护者明确同意并显式传入 `--allow-xy-bump`，否则脚本以退出码 `1` 阻断且不改动任何文件。
3. 遍历工作区全部成员与根治理文档：
   - 对所有可发布包更新 `pubspec.yaml` 的 `version` 为 `<version>`；
   - 对所有成员（包含非发布成员）更新 `dependencies` 和 `dev_dependencies` 中对其它工作区成员的约束为 `^<version>`；
   - 对所有可发布包更新 `packages/*/CHANGELOG.md`（用于 pub.dev 展示，保持英文）：若文件顶部包含 `## Unreleased` 标题，直接替换为 `## <version>`；若无未发布条目，则在顶部插入 `## <version>\n\n- Version alignment (no changes).`。
   - 同步更新全仓唯一事实源——根目录 `CHANGELOG.md`：若存在 `## [Unreleased]` 节，将其内容归档为 `## [<version>] - YYYY-MM-DD`（当 `## [Unreleased]` 为空时填入 `- 版本号对齐（无行为变更）。`），并在顶部保留 `## [Unreleased]` 节等待后续变更累积。
4. **注意事项**：
   - `hiflutter_tool` 源码与文档中不会写死版本号占位符，运行 `bump_version.dart` 不会改动业务代码。
   - 日常在开发分支若有可感知行为变更，应随 PR 同步更新根目录 `CHANGELOG.md` 的 `## [Unreleased]` 节，并在涉及包变更时按需更新对应包的英文 `packages/*/CHANGELOG.md` `## Unreleased` 节；若涉及运行环境、兼容性契约或跨版本迁移路径变更，须同步更新 [兼容性与升级指南](../compatibility.md)。
   - `dart run tool/check.dart` 的 `versions` 阶段会强制校验：全部可发布包版本一致、包间约束对齐、各子包 `CHANGELOG.md` 含 `## <version>`、根目录 `CHANGELOG.md` 含 `## [Unreleased]` 与 `## [<version>]`（允许带归档日期），以及 `docs/compatibility.md` 存在且非空。

## 发版（Git Tag）与发布（pub.dev）

**重要约定**：**发版**与**发布**是两项严格分离的操作，除非维护者明确下达指令，否则任何代码实施、PR 合并或日常维护均**不得修改 `main` 分支、不得打任何 Git tag、不得运行不带 `--dry-run` 的 `pub publish`**。制作期日常提交仅在分支演进，不打 Git 标签、不向 pub.dev 发布。

### 发版流程（在 `main` 打裸 `<version>` Git Tag，供锁定模式消费）

仅在维护者明确决定为某个版本发版时执行：

1. 在 `dev` 分支运行 `dart run tool/bump_version.dart <version>`（若涉及 `x` 或 `y` 变更须经维护者明确同意并传入 `--allow-xy-bump`）统一对齐版本与 `CHANGELOG.md`，确认各破坏性改动包的迁移要点完整。
2. 运行全量验证（包含示例 App 原生构建冒烟）：
   ```bash
   flutter pub get
   dart run tool/check.dart --build
   ```
   确认全部阶段通过，工作区完全干净。
3. 将 `dev` 合入 `main` 并推送 `main`。
4. 在 `main` 的发版提交上打 Annotated Tag（不带 `v` 前缀的裸 `<version>`）并推送：
   ```bash
   git tag -a <version> -m "Release <version>"
   git push origin <version>
   ```
5. **不可覆盖原则**：已经打出的发版 tag（及已发布版本）视为不可变快照，**绝不移动、删除重建或覆盖已发版裸 `x.y.z` 标签**，也绝不 `--force` 推送 `main` 或已发版裸 `x.y.z` 标签。发现问题必须通过递增 `z` 版本发新标签解决。

### 发布流程（上传至 pub.dev，供发布模式消费）

仅在维护者明确指令对外公开发布（例如首次正式对外发布定为 `1.0.0`，或后续已发版版本的公开传播）时执行：

1. 切换到已打好且通过 `dart run tool/check.dart --build` 的 `<version>`（如 `1.0.0`）裸发版 tag 对应提交，再次核对 `publish` 阶段（`pub publish --dry-run`）全数零警告零错误。
2. 按无环拓扑依赖顺序逐层发布到 pub.dev（`hiflutter_base` → 其余 5 个契约包与 `hiflutter_base_log_file` → 各适配包 → `hiflutter_riverpod` → 伞包 `hiflutter` → 工具包 `hiflutter_tool`）。
3. 将早期旧版 pub.dev 上的 `hi_*` 包按 [ADR-0001](../adr/0001-hiflutter-package-prefix.md) 标记为 discontinued 并引导至对应的 `hiflutter` / `hiflutter_*` 新包。

## 维护分支规则

- **默认策略**：鼓励消费项目通过 `hiflutter mode pin <最新tag>` 直接升级到最新版本并对照 `CHANGELOG.md` 适配。
- **维护分支与 `x.y.*` 热修通道**：在 `1.0.0` 后项目周期批次演进模型下，同批次某个消费项目提审上架并锁定发版 `x.y.z` 后，其余仍在源码开发的消费项目会立即切入 `x.(y+1).0` 继续演进，原 `x.y.*` 即留作该已上架消费项目的独立紧急热修通道。当已发版/已上架消费项目遇到阻塞性问题、且此时 `dev`/`main` 已切入更高 `x.(y+1).*` 批次导致升级代价过大时，维护者方可决定启用维护分支：
  1. 从该消费项目当前锁定的裸发版 tag（如 `1.0.0`）切出维护分支（如 `maint/1.0`）；
  2. 只在该分支合入最小修复补丁；
  3. 对维护分支执行 `z` 版本号递增（如 `1.0.1`），跑通完整 `dart run tool/check.dart --build`，在维护分支对应修复提交上打出裸补丁 tag `1.0.1`（不得回合并覆写原 tag，按需另行把修复 cherry-pick 回 `dev`）。
