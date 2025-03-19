import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:yaml_edit/yaml_edit.dart';

class CreateConfigCommand extends Command<int> {
  @override
  final name = 'create-config';
  @override
  final description = 'Creates or updates the localization configuration file';

  bool testMode = false;
  File? testFile;
  bool? testUserInput;
  ArgResults? testArgResults;

  static const configFileName = 'gen_l10n_utils.yaml';

  CreateConfigCommand() {
    argParser.addOption(
      'base-language',
      abbr: 'b',
      help: 'Default language code (ISO 639-1)',
      defaultsTo: 'en',
    );
    argParser.addMultiOption(
      'languages',
      abbr: 'l',
      help: 'Language codes to support (comma separated)',
      defaultsTo: ['en'],
      splitCommas: true,
    );
    argParser.addOption(
      'export-format',
      abbr: 'f',
      help: 'Default export format for translations (e.g., xlf)',
    );
  }

  bool _askUserConfirmation(String message) {
    if (testMode) return testUserInput ?? false;

    stdout.write('$message (y/N): ');
    final input = stdin.readLineSync()?.toLowerCase();
    return input == 'y' || input == 'yes';
  }

  @override
  Future<int> run() async {
    try {
      final args = testMode ? testArgResults : argResults;
      final baseLanguage = args?['base-language'] as String;
      final languages = args?['languages'] as List<String>;
      final exportFormat = args?['export-format'] as String?;

      if (!languages.contains(baseLanguage)) {
        languages.insert(0, baseLanguage);
      }

      // Check for existing config file
      final configFilePath = testMode
          ? (testFile?.path ?? configFileName)
          : '${Directory.current.path}/$configFileName';

      final configFile = testMode ? testFile : File(configFilePath);
      final exists = configFile?.existsSync() ?? false;

      if (exists) {
        final shouldUpdate = _askUserConfirmation(
            '📝  Configuration file $configFileName already exists. Do you want to update its contents?');

        if (!shouldUpdate) {
          print('❌  Operation cancelled.');
          return 1;
        }

        // Read existing content and create editor
        final content = configFile!.readAsStringSync();
        final yamlEditor = YamlEditor(content);

        // Update values
        yamlEditor.update(['base_language'], baseLanguage);
        yamlEditor.update(['languages'], languages);

        // Only update export_format if provided
        if (exportFormat != null) {
          yamlEditor.update(['export_format'], exportFormat);
        }

        await configFile.writeAsString(yamlEditor.toString());
        print('✅  Updated configuration file: ${configFile.path}');
        return 0;
      }

      // Create new file if none exists
      final newFile =
          testMode ? (testFile ?? File(configFileName)) : File(configFileName);

      // Create YAML content directly
      var yamlContent = '''base_language: $baseLanguage
languages:
${languages.map((lang) => '  - $lang').join('\n')}
''';

      // Add export_format if provided
      if (exportFormat != null) {
        yamlContent += 'export_format: $exportFormat\n';
      }

      await newFile.writeAsString(yamlContent);
      print('✅  Created configuration file: ${newFile.path}');
      return 0;
    } catch (e) {
      stderr.writeln('❌ Error: ${e.toString()}');
      return 1;
    }
  }
}
