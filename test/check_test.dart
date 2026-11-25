import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../tool/src/stages.dart';
import 'support/fixture_repo.dart';

void main() {
  test('allStages omits build by default and appends it with includeBuild', () {
    expect(
      defaultStages().map((s) => s.id),
      equals([
        'format',
        'analyze',
        'test',
        'deps',
        'terms',
        'versions',
        'publish',
        'e2e',
      ]),
    );
    expect(
      allStages(includeBuild: true).map((s) => s.id),
      equals([
        'format',
        'analyze',
        'test',
        'deps',
        'terms',
        'versions',
        'publish',
        'e2e',
        'build',
      ]),
    );
  });

  group('runCheck', () {
    late FixtureRepo repo;

    tearDown(() => repo.dispose());

    test('runs the Spec stages in order', () async {
      repo = await FixtureRepo.create();

      final run = await repo.check(['--help']);

      expect(
        run.output,
        contains(
          'Stages: format, analyze, test, deps, terms, versions, publish, e2e',
        ),
      );
      expect(run.output, contains('--build'));
    });

    test('build stage fails cleanly when apps/showcase is absent', () async {
      repo = await FixtureRepo.create();

      final run = await repo.check(['--only', 'build']);

      expect(run.exitCode, isNot(0), reason: '$run');
      expect(run.output, contains('FAIL build'));
      expect(run.output, contains('apps/showcase'));
    });

    test('e2e stage fails cleanly when hiflutter_net is absent', () async {
      repo = await FixtureRepo.create(packages: ['hiflutter_base']);

      final run = await repo.check(['--only', 'e2e']);

      expect(run.exitCode, isNot(0), reason: '$run');
      expect(run.output, contains('FAIL e2e'));
      expect(run.output, contains('hiflutter_net'));
    });

    test('rejects an unknown stage id', () async {
      repo = await FixtureRepo.create();

      final run = await repo.check(['--only', 'nope']);

      expect(run.exitCode, 64);
      expect(run.output, contains('Unknown stage(s): nope'));
    });

    group('format stage', () {
      test('passes on a formatted workspace', () async {
        repo = await FixtureRepo.create();

        final run = await repo.check(['--only', 'format']);

        expect(run.exitCode, 0, reason: '$run');
      });

      test('fails when a Dart file is not formatted', () async {
        repo = await FixtureRepo.create();
        repo.write(
          'packages/hiflutter_base/lib/ugly.dart',
          'int   x(  )=>1;\n',
        );

        final run = await repo.check(['--only', 'format']);

        expect(run.exitCode, isNot(0), reason: '$run');
        expect(run.output, contains('FAIL format'));
      });
    });

    group('versions stage', () {
      test('passes when every package shares one version', () async {
        repo = await FixtureRepo.create(
          packages: ['hiflutter_base', 'hiflutter_net'],
        );

        final run = await repo.check(['--only', 'versions']);

        expect(run.exitCode, 0, reason: '$run');
      });

      test('fails when packages have different versions', () async {
        repo = await FixtureRepo.create(
          packages: ['hiflutter_base', 'hiflutter_net'],
        );
        repo.addPackage('hiflutter_net', version: '0.2.0');

        final run = await repo.check(['--only', 'versions']);

        expect(run.exitCode, isNot(0), reason: '$run');
        expect(run.output, contains('FAIL versions'));
        expect(run.output, contains('hiflutter_net'));
      });

      test('fails when an inter-package constraint is not ^version', () async {
        repo = await FixtureRepo.create(
          packages: ['hiflutter_base', 'hiflutter_net'],
        );
        repo.addPackage(
          'hiflutter_net',
          dependencies: {'hiflutter_base': '^0.0.9'},
        );

        final run = await repo.check(['--only', 'versions']);

        expect(run.exitCode, isNot(0), reason: '$run');
        expect(run.output, contains('hiflutter_net -> hiflutter_base'));
      });

      test('fails when a CHANGELOG lacks the current version header', () async {
        repo = await FixtureRepo.create();
        repo.addPackage('hiflutter_base', changelog: '## 0.0.1\n\n- Old.\n');

        final run = await repo.check(['--only', 'versions']);

        expect(run.exitCode, isNot(0), reason: '$run');
        expect(run.output, contains('CHANGELOG'));
      });

      test(
        'fails when an unpublished member drifts from ^version constraint',
        () async {
          repo = await FixtureRepo.create(packages: ['hiflutter_base']);
          repo.write('pubspec.yaml', '''
name: fixture_workspace
publish_to: none
environment:
  sdk: ^3.14.0
workspace:
  - apps/showcase
  - packages/hiflutter_base
''');
          repo.write('apps/showcase/pubspec.yaml', '''
name: hiflutter_showcase
publish_to: none
version: 0.1.0+1
environment:
  sdk: ^3.14.0
resolution: workspace
dependencies:
  hiflutter_base: ^0.0.9
''');

          final run = await repo.check(['--only', 'versions']);

          expect(run.exitCode, isNot(0), reason: '$run');
          expect(run.output, contains('hiflutter_showcase -> hiflutter_base'));
        },
      );

      test('fails when root CHANGELOG.md is missing', () async {
        repo = await FixtureRepo.create();
        File(p.join(repo.root, 'CHANGELOG.md')).deleteSync();

        final run = await repo.check(['--only', 'versions']);

        expect(run.exitCode, isNot(0), reason: '$run');
        expect(run.output, contains('FAIL versions'));
        expect(run.output, contains('CHANGELOG.md'));
      });

      test('fails when root CHANGELOG.md lacks ## [Unreleased]', () async {
        repo = await FixtureRepo.create();
        repo.write('CHANGELOG.md', '''
# 变更日志（Changelog）

## [0.1.0]

- Fixture release.
''');

        final run = await repo.check(['--only', 'versions']);

        expect(run.exitCode, isNot(0), reason: '$run');
        expect(run.output, contains('FAIL versions'));
        expect(run.output, contains('[Unreleased]'));
      });

      test('fails when root CHANGELOG.md lacks ## [<sharedVersion>]', () async {
        repo = await FixtureRepo.create();
        repo.write('CHANGELOG.md', '''
# 变更日志（Changelog）

## [Unreleased]

## [0.0.1]

- Old release.
''');

        final run = await repo.check(['--only', 'versions']);

        expect(run.exitCode, isNot(0), reason: '$run');
        expect(run.output, contains('FAIL versions'));
        expect(run.output, contains('[0.1.0]'));
      });

      test('fails when docs/compatibility.md is missing or empty', () async {
        repo = await FixtureRepo.create();
        File(p.join(repo.root, 'docs', 'compatibility.md')).deleteSync();

        final missingRun = await repo.check(['--only', 'versions']);

        expect(missingRun.exitCode, isNot(0), reason: '$missingRun');
        expect(missingRun.output, contains('FAIL versions'));
        expect(missingRun.output, contains('docs/compatibility.md'));

        repo.write('docs/compatibility.md', '   \n\n');
        final emptyRun = await repo.check(['--only', 'versions']);

        expect(emptyRun.exitCode, isNot(0), reason: '$emptyRun');
        expect(emptyRun.output, contains('FAIL versions'));
        expect(emptyRun.output, contains('docs/compatibility.md'));
      });

      test(
        'ignores ## [Unreleased] and version headers inside fenced code blocks',
        () async {
          repo = await FixtureRepo.create();
          repo.write('CHANGELOG.md', '''
# 变更日志（Changelog）

````markdown
## [Unreleased]

## [0.1.1]

```
假闭合行，不应提前结束四反引号围栏
```

## [0.1.0]
````

~~~markdown
## [Unreleased]
## [0.1.1]
~~~

## [Unreleased]

- 新增文档示例说明。

## [0.1.0]

- Fixture release.
''');

          final run = await repo.check(['--only', 'versions']);

          expect(run.exitCode, 0, reason: '$run');
        },
      );

      test('fails when shared version header only appears inside a fenced code block', () async {
        repo = await FixtureRepo.create();
        repo.write('CHANGELOG.md', '''
# 变更日志（Changelog）

## [Unreleased]

```markdown
## [0.1.0]

- 示例占位。
```
''');

        final run = await repo.check(['--only', 'versions']);

        expect(run.exitCode, isNot(0), reason: '$run');
        expect(run.output, contains('FAIL versions'));
        expect(run.output, contains('[0.1.0]'));
      });
    });

    group('deps stage', () {
      test('passes for dependencies allowed by the package table', () async {
        repo = await FixtureRepo.create(
          packages: ['hiflutter_base', 'hiflutter_net'],
        );
        repo.addPackage(
          'hiflutter_net',
          dependencies: {'hiflutter_base': '^0.1.0', 'meta': '^1.16.0'},
        );

        final run = await repo.check(['--only', 'deps']);

        expect(run.exitCode, 0, reason: '$run');
      });

      test('fails for a dependency direction the table forbids', () async {
        repo = await FixtureRepo.create(
          packages: ['hiflutter_base', 'hiflutter_net', 'hiflutter_store'],
        );
        repo.addPackage(
          'hiflutter_net',
          dependencies: {'hiflutter_store': '^0.1.0'},
        );

        final run = await repo.check(['--only', 'deps']);

        expect(run.exitCode, isNot(0), reason: '$run');
        expect(run.output, contains('FAIL deps'));
        expect(run.output, contains('hiflutter_net -> hiflutter_store'));
      });

      test('fails when a contract package depends on a third party', () async {
        repo = await FixtureRepo.create();
        repo.addPackage('hiflutter_base', dependencies: {'http': '^1.5.0'});

        final run = await repo.check(['--only', 'deps']);

        expect(run.exitCode, isNot(0), reason: '$run');
        expect(run.output, contains('hiflutter_base -> http'));
      });

      test('lets Flutter contracts, not pure Dart ones, use the SDK', () async {
        repo = await FixtureRepo.create(
          packages: ['hiflutter_base', 'hiflutter_core'],
        );
        const flutterSdk = '\n    sdk: flutter';
        repo.addPackage(
          'hiflutter_core',
          dependencies: {'flutter': flutterSdk},
        );

        expect((await repo.check(['--only', 'deps'])).exitCode, 0);

        repo.addPackage(
          'hiflutter_base',
          dependencies: {'flutter': flutterSdk},
        );
        final run = await repo.check(['--only', 'deps']);

        expect(run.exitCode, isNot(0), reason: '$run');
        expect(run.output, contains('hiflutter_base -> flutter'));
      });

      test('fails for a package missing from the table', () async {
        repo = await FixtureRepo.create(packages: ['hiflutter_extra']);

        final run = await repo.check(['--only', 'deps']);

        expect(run.exitCode, isNot(0), reason: '$run');
        expect(run.output, contains('hiflutter_extra'));
      });

      test('reports dependency cycles', () async {
        repo = await FixtureRepo.create(
          packages: ['hiflutter_base', 'hiflutter_net'],
        );
        repo.addPackage(
          'hiflutter_base',
          dependencies: {'hiflutter_net': '^0.1.0'},
        );
        repo.addPackage(
          'hiflutter_net',
          dependencies: {'hiflutter_base': '^0.1.0'},
        );

        final run = await repo.check(['--only', 'deps']);

        expect(run.exitCode, isNot(0), reason: '$run');
        expect(run.output, contains('dependency cycle: hiflutter_base'));
      });
    });

    group('terms stage', () {
      final term = businessTerms().first;

      test('passes when no business term appears', () async {
        repo = await FixtureRepo.create();

        final run = await repo.check(['--only', 'terms']);

        expect(run.exitCode, 0, reason: '$run');
      });

      test('fails on a business term in any letter case', () async {
        repo = await FixtureRepo.create();
        repo.write(
          'packages/hiflutter_base/README.md',
          'Built for ${term.toLowerCase()}.\n',
        );

        final run = await repo.check(['--only', 'terms']);

        expect(run.exitCode, isNot(0), reason: '$run');
        expect(run.output, contains('FAIL terms'));
        expect(run.output, contains('packages/hiflutter_base/README.md:1'));
      });

      test('fails on a business term in a file path', () async {
        repo = await FixtureRepo.create();
        repo.write('docs/${term.toUpperCase()}.md', 'Nothing here.\n');

        final run = await repo.check(['--only', 'terms']);

        expect(run.exitCode, isNot(0), reason: '$run');
        expect(run.output, contains('docs/${term.toUpperCase()}.md'));
      });
    });
  });
}
