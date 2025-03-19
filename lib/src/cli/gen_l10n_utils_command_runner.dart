import 'package:args/command_runner.dart';
import 'commands/create_config_command.dart';
import 'commands/export_command.dart';
import 'commands/gen_arb_command.dart';
import 'commands/translate_command.dart';

class GenL10nUtilsCommandRunner extends CommandRunner<int> {
  GenL10nUtilsCommandRunner()
      : super(
          'gen_l10n_utils',
          'Utility tools for Flutter\'s gen_l10n localization',
        ) {
    addCommand(CreateConfigCommand());
    addCommand(ExportCommand());
    addCommand(GenArbCommand());
    addCommand(TranslateCommand());
  }
}
