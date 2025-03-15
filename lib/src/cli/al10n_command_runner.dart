import 'package:args/command_runner.dart';
import 'commands/create_config_command.dart';
import 'commands/gen_arb_command.dart';

class Al10nCommandRunner extends CommandRunner<int> {
  Al10nCommandRunner()
      : super(
    'al10n',
    'AppMinds Localization Tools for Flutter apps',
  ) {
    addCommand(CreateConfigCommand());
    addCommand(GenArbCommand());
  }
}