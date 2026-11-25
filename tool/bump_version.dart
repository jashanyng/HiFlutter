import 'dart:io';

import 'src/bump_version.dart';

/// Entry point of `dart run tool/bump_version.dart [--root <dir>] [--allow-xy-bump] <version>`; see
/// `tool/src/bump_version.dart`.
Future<void> main(List<String> args) async {
  exitCode = await runBumpVersion(args);
}
