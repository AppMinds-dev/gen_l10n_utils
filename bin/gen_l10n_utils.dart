import 'dart:io';
import 'package:gen_l10n_utils/src/cli/gen_l10n_utils_command_runner.dart';

void main(List<String> arguments) async {
  final runner = GenL10nUtilsCommandRunner();
  try {
    final exitCode = await runner.run(arguments) ?? 0;
    exit(exitCode);
  } catch (e) {
    stderr.writeln(e);
    exit(1);
  }
}