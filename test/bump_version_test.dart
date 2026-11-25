import 'package:test/test.dart';

import 'support/fixture_repo.dart';

void main() {
  late FixtureRepo repo;

  tearDown(() => repo.dispose());

  test(
    'moves every package and inter-package constraint to the version',
    () async {
      repo = await FixtureRepo.create(
        packages: ['hiflutter_base', 'hiflutter_net'],
      );
      repo.addPackage(
        'hiflutter_net',
        dependencies: {'hiflutter_base': '^0.1.0', 'meta': '^1.16.0'},
      );

      final run = await repo.bumpVersion(['0.1.1']);

      expect(run.exitCode, 0, reason: '$run');
      final net = repo.read('packages/hiflutter_net/pubspec.yaml');
      expect(net, contains('version: 0.1.1'));
      expect(net, contains('hiflutter_base: ^0.1.1'));
      expect(net, contains('meta: ^1.16.0'));
      expect(
        repo.read('packages/hiflutter_base/pubspec.yaml'),
        contains('version: 0.1.1'),
      );
      final check = await repo.check(['--only', 'versions']);
      expect(check.exitCode, 0, reason: '$check');
    },
  );

  test(
    'releases Unreleased entries and aligns packages without changes',
    () async {
      repo = await FixtureRepo.create(
        packages: ['hiflutter_base', 'hiflutter_net'],
      );
      repo.addPackage(
        'hiflutter_base',
        changelog: '## Unreleased\n\n- Add retry.\n\n## 0.1.0\n\n- Initial.\n',
      );

      final run = await repo.bumpVersion(['0.1.1']);

      expect(run.exitCode, 0, reason: '$run');
      expect(
        repo.read('packages/hiflutter_base/CHANGELOG.md'),
        '## 0.1.1\n\n- Add retry.\n\n## 0.1.0\n\n- Initial.\n',
      );
      expect(
        repo.read('packages/hiflutter_net/CHANGELOG.md'),
        '## 0.1.1\n\n- Version alignment (no changes).\n\n## 0.1.0\n\n- Fixture.\n',
      );
    },
  );

  test('updates constraints, not version, of unpublished members', () async {
    repo = await FixtureRepo.create();
    repo.write('pubspec.yaml', '''
name: fixture_workspace
publish_to: none
environment:
  sdk: ^3.14.0
workspace:
  - packages/hiflutter_base
  - apps/showcase
''');
    repo.write('apps/showcase/pubspec.yaml', '''
name: showcase
publish_to: none
version: 1.0.0+1
environment:
  sdk: ^3.14.0
resolution: workspace
dependencies:
  hiflutter_base: ^0.1.0
''');

    final run = await repo.bumpVersion(['0.1.1']);

    expect(run.exitCode, 0, reason: '$run');
    final showcase = repo.read('apps/showcase/pubspec.yaml');
    expect(showcase, contains('hiflutter_base: ^0.1.1'));
    expect(showcase, contains('version: 1.0.0+1'));
  });

  test('allows pure z increment from 0.0.1 without --allow-xy-bump', () async {
    repo = await FixtureRepo.create(
      packages: ['hiflutter_base', 'hiflutter_net'],
      version: '0.0.1',
    );
    repo.addPackage(
      'hiflutter_net',
      version: '0.0.1',
      dependencies: {'hiflutter_base': '^0.0.1'},
    );

    final run = await repo.bumpVersion(['0.0.2']);

    expect(run.exitCode, 0, reason: '$run');
    expect(
      repo.read('packages/hiflutter_base/pubspec.yaml'),
      contains('version: 0.0.2'),
    );
    final net = repo.read('packages/hiflutter_net/pubspec.yaml');
    expect(net, contains('version: 0.0.2'));
    expect(net, contains('hiflutter_base: ^0.0.2'));
    expect(
      repo.read('packages/hiflutter_base/CHANGELOG.md'),
      contains('## 0.0.2'),
    );
  });

  test('blocks x or y changes unless --allow-xy-bump is passed', () async {
    repo = await FixtureRepo.create(version: '0.0.1');
    final pubspecBefore = repo.read('packages/hiflutter_base/pubspec.yaml');
    final changelogBefore = repo.read('packages/hiflutter_base/CHANGELOG.md');

    final minorRun = await repo.bumpVersion(['0.1.0']);
    expect(minorRun.exitCode, 1, reason: '$minorRun');
    expect(minorRun.output, contains('--allow-xy-bump'));
    expect(repo.read('packages/hiflutter_base/pubspec.yaml'), pubspecBefore);
    expect(repo.read('packages/hiflutter_base/CHANGELOG.md'), changelogBefore);

    final majorRun = await repo.bumpVersion(['1.0.0']);
    expect(majorRun.exitCode, 1, reason: '$majorRun');
    expect(majorRun.output, contains('--allow-xy-bump'));
    expect(repo.read('packages/hiflutter_base/pubspec.yaml'), pubspecBefore);
    expect(repo.read('packages/hiflutter_base/CHANGELOG.md'), changelogBefore);
  });

  test('allows x or y bump when --allow-xy-bump is passed and still checks progress', () async {
    repo = await FixtureRepo.create(version: '0.0.1');

    final minorRun = await repo.bumpVersion(['--allow-xy-bump', '0.1.0']);
    expect(minorRun.exitCode, 0, reason: '$minorRun');
    expect(
      repo.read('packages/hiflutter_base/pubspec.yaml'),
      contains('version: 0.1.0'),
    );

    final majorRun = await repo.bumpVersion(['--allow-xy-bump', '1.0.0']);
    expect(majorRun.exitCode, 0, reason: '$majorRun');
    expect(
      repo.read('packages/hiflutter_base/pubspec.yaml'),
      contains('version: 1.0.0'),
    );

    final staleSame = await repo.bumpVersion(['--allow-xy-bump', '1.0.0']);
    expect(staleSame.exitCode, 1, reason: '$staleSame');

    final staleLower = await repo.bumpVersion(['--allow-xy-bump', '0.9.9']);
    expect(staleLower.exitCode, 1, reason: '$staleLower');
  });

  test('rejects non-bare x.y.z versions without touching files', () async {
    repo = await FixtureRepo.create();
    final before = repo.read('packages/hiflutter_base/pubspec.yaml');

    for (final invalid in ['v0.2', 'v0.1.1', '0.1.1-dev.1', '0.1.1+1']) {
      final run = await repo.bumpVersion([invalid]);

      expect(run.exitCode, 64, reason: '$invalid -> $run');
      expect(run.output, contains(invalid));
      expect(repo.read('packages/hiflutter_base/pubspec.yaml'), before);
    }
  });

  test('refuses a version that does not move forward', () async {
    repo = await FixtureRepo.create(version: '0.2.0');
    final before = repo.read('packages/hiflutter_base/CHANGELOG.md');

    final run = await repo.bumpVersion(['0.2.0']);

    expect(run.exitCode, 1, reason: '$run');
    expect(run.output, contains('hiflutter_base is already at 0.2.0'));
    expect(repo.read('packages/hiflutter_base/CHANGELOG.md'), before);
  });

  test('archives root CHANGELOG.md Unreleased section with date while keeping top Unreleased', () async {
    repo = await FixtureRepo.create(
      packages: ['hiflutter_base', 'hiflutter_net'],
    );
    repo.write('CHANGELOG.md', '''
# 变更日志（Changelog）

说明段落。

## [Unreleased]

- 新增 `HiRetryPolicy` 重试策略。

## [0.1.0]

- Fixture release.
''');

    final run = await repo.bumpVersion(['0.1.1']);

    expect(run.exitCode, 0, reason: '$run');
    final now = DateTime.now();
    final today =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    expect(repo.read('CHANGELOG.md'), '''
# 变更日志（Changelog）

说明段落。

## [Unreleased]

## [0.1.1] - $today

- 新增 `HiRetryPolicy` 重试策略。

## [0.1.0]

- Fixture release.
''');
    final check = await repo.check(['--only', 'versions']);
    expect(check.exitCode, 0, reason: '$check');
  });

  test(
    'fills default alignment entry when root CHANGELOG.md Unreleased is empty',
    () async {
      repo = await FixtureRepo.create(
        packages: ['hiflutter_base', 'hiflutter_net'],
      );

      final run = await repo.bumpVersion(['0.1.1']);

      expect(run.exitCode, 0, reason: '$run');
      final now = DateTime.now();
      final today =
          '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';
      expect(repo.read('CHANGELOG.md'), '''
# 变更日志（Changelog）

## [Unreleased]

## [0.1.1] - $today

- 版本号对齐（无行为变更）。

## [0.1.0]

- Fixture release.
''');
      final check = await repo.check(['--only', 'versions']);
      expect(check.exitCode, 0, reason: '$check');
    },
  );

  test(
    'fails without mutating packages when root CHANGELOG.md is invalid',
    () async {
      repo = await FixtureRepo.create(version: '0.0.1');
      repo.write(
        'CHANGELOG.md',
        '# 变更日志（Changelog）\n\n## [0.0.1]\n\n- 缺失 Unreleased。\n',
      );
      final pubspecBefore = repo.read('packages/hiflutter_base/pubspec.yaml');

      final run = await repo.bumpVersion(['0.0.2']);

      expect(run.exitCode, 1, reason: '$run');
      expect(run.output, contains('Unreleased'));
      expect(repo.read('packages/hiflutter_base/pubspec.yaml'), pubspecBefore);
    },
  );

  test('preserves fenced code blocks containing Unreleased and target version examples', () async {
    repo = await FixtureRepo.create(
      packages: ['hiflutter_base', 'hiflutter_net'],
    );
    repo.write('CHANGELOG.md', '''
# 变更日志（Changelog）

## [Unreleased]

- 新增围栏示例与升级说明：

````markdown
## [Unreleased]

## [0.1.1]

```
## [0.1.1]
```
````

- 示例后半段说明。

## [0.1.0]

~~~markdown
## [Unreleased]

## [0.1.1]
~~~

- Fixture release.
''');

    final run = await repo.bumpVersion(['0.1.1']);

    expect(run.exitCode, 0, reason: '$run');
    final now = DateTime.now();
    final today =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    expect(repo.read('CHANGELOG.md'), '''
# 变更日志（Changelog）

## [Unreleased]

## [0.1.1] - $today

- 新增围栏示例与升级说明：

````markdown
## [Unreleased]

## [0.1.1]

```
## [0.1.1]
```
````

- 示例后半段说明。

## [0.1.0]

~~~markdown
## [Unreleased]

## [0.1.1]
~~~

- Fixture release.
''');
    final check = await repo.check(['--only', 'versions']);
    expect(check.exitCode, 0, reason: '$check');
  });
}
