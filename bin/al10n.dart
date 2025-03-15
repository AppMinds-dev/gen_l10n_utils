import 'dart:io';
import 'package:appminds_l10n_tools/src/cli/al10n_command_runner.dart';

void main(List<String> arguments) async {
  final runner = Al10nCommandRunner();
  try {
    final exitCode = await runner.run(arguments) ?? 0;
    exit(exitCode);
  } catch (e) {
    stderr.writeln(e);
    exit(1);
  }
}