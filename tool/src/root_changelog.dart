import 'dart:io';

import 'package:path/path.dart' as p;

/// Entry written to the root `CHANGELOG.md` when `## [Unreleased]` is empty.
const String rootAlignedEntry = '- 版本号对齐（无行为变更）。';

/// Matches the opening line of a Markdown fenced code block (backticks or tildes).
final _fenceOpenPattern = RegExp(r'^[ \t]{0,3}(`{3,}|~{3,})');

/// Matches the root changelog section header collecting unreleased entries.
final _rootUnreleased = RegExp(r'^## \[Unreleased\][ \t]*$', multiLine: true);

/// Matches any level-2 markdown heading.
final _level2Heading = RegExp(r'^## ', multiLine: true);

/// Builds the level-2 heading matcher for [version] in the root changelog.
RegExp _rootVersionHeader(String version) => RegExp(
  '^## \\[${RegExp.escape(version)}\\](?: - \\d{4}-\\d{2}-\\d{2})?[ \\t]*\$',
  multiLine: true,
);

/// Masks Markdown fenced code blocks in [text] while preserving line breaks and
/// UTF-16 character offsets.
///
/// Line endings are first normalized from `\r\n` to `\n`. Every line belonging
/// to a fenced code block (opening fence, body lines, and closing fence) has
/// all non-newline characters replaced with `' '`.
String maskFencedCodeBlocks(String text) {
  final normalized = text.replaceAll('\r\n', '\n');
  final lines = normalized.split('\n');
  final masked = List<String>.filled(lines.length, '');
  String? fenceChar;
  var fenceLength = 0;

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (fenceChar == null) {
      final match = _fenceOpenPattern.firstMatch(line);
      if (match != null) {
        final fence = match.group(1)!;
        fenceChar = fence[0];
        fenceLength = fence.length;
        masked[i] = ' ' * line.length;
      } else {
        masked[i] = line;
      }
    } else {
      masked[i] = ' ' * line.length;
      final closePattern = RegExp(
        '^[ \\t]{0,3}${RegExp.escape(fenceChar)}{$fenceLength,}[ \\t]*\$',
      );
      if (closePattern.hasMatch(line)) {
        fenceChar = null;
        fenceLength = 0;
      }
    }
  }
  return masked.join('\n');
}

/// Validates root `CHANGELOG.md` and `docs/compatibility.md` under [root].
///
/// Headings inside Markdown fenced code blocks are ignored. When
/// [sharedVersion] is non-null, verifies that a matching `## [<sharedVersion>]`
/// heading exists outside fenced code blocks.
List<String> validateRootGovernanceDocs(String root, {String? sharedVersion}) {
  final problems = <String>[];
  final rootChangelog = File(p.join(root, 'CHANGELOG.md'));
  if (!rootChangelog.existsSync()) {
    problems.add('Root CHANGELOG.md is missing');
  } else {
    final masked = maskFencedCodeBlocks(rootChangelog.readAsStringSync());
    final unreleasedMatches = _rootUnreleased.allMatches(masked).length;
    if (unreleasedMatches != 1) {
      problems.add(
        'Root CHANGELOG.md must contain exactly one "## [Unreleased]" header',
      );
    }
    if (sharedVersion != null &&
        !_rootVersionHeader(sharedVersion).hasMatch(masked)) {
      problems.add('Root CHANGELOG.md lacks a "## [$sharedVersion]" header');
    }
  }

  final compatibility = File(p.join(root, 'docs', 'compatibility.md'));
  if (!compatibility.existsSync()) {
    problems.add('Missing docs/compatibility.md');
  } else if (compatibility.readAsStringSync().trim().isEmpty) {
    problems.add('docs/compatibility.md must not be empty');
  }
  return problems;
}

/// Validates root `CHANGELOG.md` under [root] before archiving [version].
///
/// Returns an error message when the file is missing, does not contain
/// exactly one `## [Unreleased]` heading outside fenced code blocks, or already
/// contains a heading for [version] outside fenced code blocks.
String? validateRootChangelogForArchive(String root, String version) {
  final file = File(p.join(root, 'CHANGELOG.md'));
  if (!file.existsSync()) {
    return 'Missing root CHANGELOG.md at ${file.path}';
  }
  final masked = maskFencedCodeBlocks(file.readAsStringSync());
  if (_rootUnreleased.allMatches(masked).length != 1) {
    return 'Root CHANGELOG.md must contain exactly one "## [Unreleased]" header';
  }
  if (_rootVersionHeader(version).hasMatch(masked)) {
    return 'Root CHANGELOG.md already contains "## [$version]"';
  }
  return null;
}

/// Returns updated root changelog content with `## [Unreleased]` archived into
/// `## [<version>] - YYYY-MM-DD` for [date].
///
/// Heading offsets are resolved against [maskFencedCodeBlocks] and sliced from
/// the `\n`-normalized original text so fenced code blocks inside entries are
/// preserved verbatim.
String archiveRootChangelogText(String text, String version, DateTime date) {
  final normalized = text.replaceAll('\r\n', '\n');
  final masked = maskFencedCodeBlocks(normalized);
  final match = _rootUnreleased.allMatches(masked).single;
  final dateStr =
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
  final nextHeading = _level2Heading.firstMatch(masked.substring(match.end));
  final sectionEnd = nextHeading == null
      ? normalized.length
      : match.end + nextHeading.start;
  final rawBody = normalized.substring(match.end, sectionEnd).trim();
  final effectiveBody = rawBody.isEmpty ? rootAlignedEntry : rawBody;
  final suffix = sectionEnd == normalized.length ? '\n' : '\n\n';
  final replacement =
      '## [Unreleased]\n\n## [$version] - $dateStr\n\n$effectiveBody$suffix';
  return '${normalized.substring(0, match.start)}'
      '$replacement'
      '${normalized.substring(sectionEnd)}';
}

/// Archives the root `CHANGELOG.md` `## [Unreleased]` section under [root]
/// into `## [<version>] - YYYY-MM-DD` for [date] while preserving `## [Unreleased]`.
void archiveRootChangelog(String root, String version, DateTime date) {
  final file = File(p.join(root, 'CHANGELOG.md'));
  final updated = archiveRootChangelogText(
    file.readAsStringSync(),
    version,
    date,
  );
  file.writeAsStringSync(updated);
}
