import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';
import 'package:yaml_edit/yaml_edit.dart';

import 'workspace.dart';

/// Moves every HiFlutter package to one bare `x.y.z` version and returns an exit code.
///
/// Usage: `dart run tool/bump_version.dart [--root <dir>] [--allow-xy-bump] <version>`.
///
/// By default only pure patch (`z`) increments are allowed. Changing `x` or `y`
/// requires explicit `--allow-xy-bump` confirmation from the maintainer.
///
/// For every workspace member it rewrites constraints on other members to
/// `^<version>`; for every publishable member it also sets `version`.
Future<int> runBumpVersion(List<String> args, {StringSink? out}) async {
  final sink = out ?? stdout;
  const usage =
      'Usage: dart run tool/bump_version.dart [--root <dir>] [--allow-xy-bump] <version>';
  final parser = ArgParser()
    ..addOption('root', help: 'Workspace root to bump.')
    ..addFlag(
      'allow-xy-bump',
      negatable: false,
      help: 'Allow changing major (x) or minor (y) version with maintainer approval.',
    )
    ..addFlag('help', abbr: 'h', negatable: false);

  final ArgResults options;
  try {
    options = parser.parse(args);
  } on FormatException catch (e) {
    sink.writeln('${e.message}\n\n$usage\n${parser.usage}');
    return 64;
  }
  if (options.flag('help')) {
    sink.writeln('$usage\n${parser.usage}');
    return 0;
  }
  if (options.rest.length != 1) {
    sink.writeln('Expected exactly one version.\n\n$usage');
    return 64;
  }
  final rawVersion = options.rest.single;
  final Version version;
  if (!_bareVersion.hasMatch(rawVersion)) {
    sink.writeln('Not a bare x.y.z version: "$rawVersion"');
    return 64;
  }
  try {
    version = Version.parse(rawVersion);
  } on FormatException {
    sink.writeln('Not a bare x.y.z version: "$rawVersion"');
    return 64;
  }

  final root = p.normalize(
    p.absolute(options.option('root') ?? _defaultRoot()),
  );
  final packages = loadWorkspace(root);
  final names = {for (final pkg in packages) pkg.name};

  final stale = [
    for (final pkg in packages)
      if (pkg.publishable && pkg.version != null)
        if (Version.parse(pkg.version!) case final current
            when current >= version)
          '${pkg.name} is already at $current',
  ];
  if (stale.isNotEmpty) {
    sink.writeln('Version $version does not move forward:');
    for (final line in stale) {
      sink.writeln('  - $line');
    }
    return 1;
  }

  final allowXyBump = options.flag('allow-xy-bump');
  if (!allowXyBump) {
    final xyChanges = [
      for (final pkg in packages)
        if (pkg.publishable && pkg.version != null)
          if (Version.parse(pkg.version!) case final current
              when current.major != version.major ||
                  current.minor != version.minor)
            '${pkg.name}: $current -> $version',
    ];
    if (xyChanges.isNotEmpty) {
      sink.writeln(
        'Changing major (x) or minor (y) version requires explicit '
        '--allow-xy-bump with maintainer approval:',
      );
      for (final line in xyChanges) {
        sink.writeln('  - $line');
      }
      return 1;
    }
  }

  for (final pkg in packages) {
    final file = File(p.join(pkg.dir, 'pubspec.yaml'));
    final editor = YamlEditor(file.readAsStringSync());
    if (pkg.publishable) editor.update(['version'], '$version');
    for (final (section, deps) in [
      ('dependencies', pkg.dependencies),
      ('dev_dependencies', pkg.devDependencies),
    ]) {
      for (final dep in deps.keys.where(names.contains)) {
        editor.update([section, dep], '^$version');
      }
    }
    file.writeAsStringSync(editor.toString());
    if (pkg.publishable) _addChangelogHeader(pkg.dir, version);
    sink.writeln(
      '${pkg.name}: ${pkg.publishable ? '$version' : 'constraints'}',
    );
  }
  sink.writeln('Bumped ${packages.length} package(s) to $version.');
  return 0;
}

/// Entry written for a package that changed nothing in this release.
const alignedEntry = '- Version alignment (no changes).';

/// Matches a bare `x.y.z` semantic version without a `v` prefix or suffixes.
final _bareVersion = RegExp(r'^\d+\.\d+\.\d+$');

/// Header of the section collecting changes not yet in a release.
final _unreleased = RegExp(r'^## Unreleased[ \t]*$', multiLine: true);

/// Turns `## Unreleased` into `## <version>`, or prepends a `## <version>`
/// section with [alignedEntry] when the package has no unreleased changes.
void _addChangelogHeader(String dir, Version version) {
  final file = File(p.join(dir, 'CHANGELOG.md'));
  final text = file.existsSync() ? file.readAsStringSync() : '';
  file.writeAsStringSync(
    _unreleased.hasMatch(text)
        ? text.replaceFirst(_unreleased, '## $version')
        : '## $version\n\n$alignedEntry\n\n$text',
  );
}

/// The repository containing this script (`tool/..`).
String _defaultRoot() => p.dirname(p.dirname(p.fromUri(Platform.script)));
