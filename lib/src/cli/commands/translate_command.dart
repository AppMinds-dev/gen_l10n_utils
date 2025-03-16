import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'dart:convert';

import 'package:gen_l10n_utils/src/utils/find_config_file.dart';
import 'package:gen_l10n_utils/src/utils/load_config.dart';

class TranslateCommand extends Command<int> {
  @override
  final name = 'translate';
  @override
  final description =
      'Create or update translation files for a specific language';

  // Test mode fields
  bool testMode = false;
  ArgResults? testArgResults;
  Directory? testLibDir;

  TranslateCommand() {
    argParser.addOption(
      'language',
      abbr: 'l',
      help: 'The language code to create translations for',
      mandatory: true,
    );
  }

  @override
  Future<int> run() async {
    try {
      final args = testMode ? testArgResults : argResults;
      final targetLanguage = args?['language'] as String;

      // Load config from file
      final configFile = findConfigFile(Directory.current.path);
      final config = loadConfig(configFile);
      final baseLanguage = config['base_language'] as String;

      print(
          'Creating translations for $targetLanguage based on $baseLanguage...');

      final createdFiles =
          await createEmptyTranslations(baseLanguage, targetLanguage);

      if (createdFiles == 0) {
        print(
            '⚠️ No translation files were created. Make sure your project contains directories for $baseLanguage.');
        return 1;
      }

      print('✅ Created $createdFiles translation files for $targetLanguage');
      return 0;
    } catch (e) {
      stderr.writeln('❌ Error: ${e.toString()}');
      return 1;
    }
  }

  Future<int> createEmptyTranslations(
      String baseLanguage, String targetLanguage) async {
    final baseLanguageDirs = findLanguageDirs(baseLanguage);

    if (baseLanguageDirs.isEmpty) {
      print('⚠️ No directories found for base language "$baseLanguage"');
      return 0;
    }

    int createdFiles = 0;

    for (final baseDir in baseLanguageDirs) {
      final targetDir = p.join(p.dirname(baseDir), targetLanguage);

      // Create the target directory if it doesn't exist
      Directory(targetDir).createSync(recursive: true);

      // Process all ARB files in the base directory
      final arbFiles = Directory(baseDir)
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.arb'))
          .toList();

      for (final arbFile in arbFiles) {
        final fileName = p.basename(arbFile.path);
        final targetFilePath = p.join(targetDir, fileName);

        final targetFile = File(targetFilePath);
        if (targetFile.existsSync()) {
          print('⚠️ Skipping existing file: $targetFilePath');
          continue;
        }

        // Create empty translation file with the same keys
        await createEmptyTranslationFile(arbFile.path, targetFilePath);
        createdFiles++;
      }
    }

    return createdFiles;
  }

  List<String> findLanguageDirs(String languageCode) {
    final libDir = testMode ? testLibDir : Directory('lib');
    if (libDir == null || !libDir.existsSync()) {
      print('⚠️ Could not read directory: ${libDir?.path}');
      return [];
    }

    final languageDirs = <String>[];

    void searchDirectory(Directory dir) {
      try {
        for (final entity in dir.listSync()) {
          if (entity is Directory) {
            final dirName = p.basename(entity.path);
            if (dirName == languageCode) {
              languageDirs.add(entity.path);
            } else {
              searchDirectory(entity);
            }
          }
        }
      } catch (e) {
        print('⚠️ Could not read directory: ${dir.path}');
      }
    }

    searchDirectory(libDir);
    return languageDirs;
  }

  Future<void> createEmptyTranslationFile(
      String sourcePath, String targetPath) async {
    final File sourceFile = File(sourcePath);
    final String sourceContent = await sourceFile.readAsString();

    try {
      final Map<String, dynamic> jsonData = json.decode(sourceContent);

      // Create a new map with the same keys but empty values
      final Map<String, dynamic> emptyTranslation = {};

      jsonData.forEach((key, value) {
        // Preserve metadata keys (starting with @)
        if (key.startsWith('@')) {
          emptyTranslation[key] = value;
        }
        // Preserve placeholders or ICU structures
        else if (value is Map<String, dynamic>) {
          emptyTranslation[key] = value;
        }
        // For translatable strings, use empty value
        else if (value is String) {
          emptyTranslation[key] = '';
        }
        // For any other types, just copy them
        else {
          emptyTranslation[key] = value;
        }
      });

      // Write the empty translation file with pretty formatting
      final encoder = JsonEncoder.withIndent('  ');
      final File targetFile = File(targetPath);
      await targetFile.writeAsString(encoder.convert(emptyTranslation),
          flush: true);

      print('Created: $targetPath');
    } catch (e) {
      print('⚠️ Error processing file $sourcePath: $e');
      rethrow;
    }
  }
}
