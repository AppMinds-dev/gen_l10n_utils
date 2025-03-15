import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:yaml_edit/yaml_edit.dart';
import 'package:gen_l10n_utils/src/utils/find_config_file.dart';

class CreateConfigCommand extends Command<int> {
  @override
  final name = 'create-config';
  @override
  final description = 'Creates or updates the localization configuration file';

  // Test mode fields
  bool testMode = false;
  File? testFile;
  bool? testUserInput;
  ArgResults? testArgResults;

  CreateConfigCommand() {
    argParser.addOption(
      'default-language',
      abbr: 'd',
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
      final defaultLanguage = args?['default-language'] as String;
      final languages = args?['languages'] as List<String>;
      const defaultOutputFile = 'al10n.yaml';

      if (!languages.contains(defaultLanguage)) {
        languages.insert(0, defaultLanguage);
      }

      // For existing file handling
      File? existingFile;
      if (testMode) {
        // In test mode, testFile represents an existing file if specified
        existingFile = testFile;
        if (existingFile != null && !existingFile.existsSync()) {
          existingFile = null;
        }
      } else {
        try {
          existingFile = findConfigFile(Directory.current.path);
        } catch (e) {
          // No existing file found
          existingFile = null;
        }
      }

      if (existingFile != null) {
        final shouldUpdate = _askUserConfirmation(
            '📝 Configuration file ${existingFile.path} already exists. Do you want to update its contents?');

        if (!shouldUpdate) {
          print('❌ Operation cancelled.');
          return 1;
        }

        // Read existing content and create editor
        final content = existingFile.readAsStringSync();
        final yamlEditor = YamlEditor(content);

        // Update values
        yamlEditor.update(['default_language'], defaultLanguage);
        yamlEditor.update(['languages'], languages);

        await existingFile.writeAsString(yamlEditor.toString());
        print('✅ Updated configuration file: ${existingFile.path}');
        return 0;
      }

      // Create new file if none exists
      final newFile = testMode
          ? (testFile ?? File(defaultOutputFile))
          : File(defaultOutputFile);

      // Create YAML content directly instead of using YamlEditor for a new file
      final yamlContent = '''default_language: $defaultLanguage
languages:
${languages.map((lang) => '  - $lang').join('\n')}
''';

      await newFile.writeAsString(yamlContent);
      print('✅ Created configuration file: ${newFile.path}');
      return 0;
    } catch (e) {
      stderr.writeln('❌ Error: ${e.toString()}');
      return 1;
    }
  }
}
