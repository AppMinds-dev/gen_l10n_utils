// lib/src/cli/commands/export_command.dart
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:gen_l10n_utils/src/cli/commands/gen_arb_command.dart';
import 'package:gen_l10n_utils/src/utils/arb_converter.dart';
import 'package:gen_l10n_utils/src/utils/load_config.dart';
import 'package:gen_l10n_utils/src/utils/find_config_file.dart';
import 'package:path/path.dart' as p;

class ExportCommand extends Command<int> {
  @override
  final name = 'export';

  @override
  final description = 'Exports ARB files to a specified format';

  ExportCommand() {
    argParser.addOption(
      'target',
      abbr: 't',
      help: 'Output format (xlf, json, etc.). If not specified, uses the format from config or defaults to xlf.',
    );
    argParser.addOption(
      'language',
      abbr: 'l',
      help: 'Specific language(s) to export (comma-separated). If not specified, all languages will be exported.',
    );
  }

  @override
  Future<int> run() async {
    // Get target from arguments, config file, or default to xlf
    String? target = argResults?['target'] as String?;
    final languageParam = argResults?['language'] as String?;

    // Find config file to get languages and potentially the default format
    final projectRoot = Directory.current.path;
    File? configFile;
    Map<String, dynamic>? config;

    try {
      configFile = findConfigFile(projectRoot);
      config = loadConfig(configFile);
    } catch (e) {
      print('Warning: Could not load configuration. Using default settings.');
      config = {};
    }

    // If target not specified in command, try to get from config or use default
    target ??= config['export_format'] as String? ?? 'xlf';

    // Get base language from config or default to 'en'
    final baseLanguage = config['base_language'] as String? ?? 'en';

    final List<String> languages;
    if (languageParam != null) {
      languages = languageParam.split(',').map((e) => e.trim()).toList();
    } else {
      // Get all languages from config
      try {
        languages = List<String>.from(config['languages'] ?? []);
        if (languages.isEmpty) {
          print('Error: No languages found in configuration.');
          return 1;
        }
      } catch (e) {
        print('Error loading languages from config: $e');
        return 1;
      }
    }

    // Check if ARB files exist (both simplified and metadata versions)
    final arbDir = Directory('lib/l10n');
    if (!arbDir.existsSync() || !_arbFilesExist(arbDir, languages)) {
      print('Some or all ARB files are missing.');
      stdout.write('Do you want to create them? (y/n): ');
      final response = stdin.readLineSync()?.toLowerCase();

      if (response == 'y' || response == 'yes') {
        // Run gen_arb command
        final genArbCommand = GenArbCommand();

        // Find all ARB files in the project
        final projectRoot = Directory.current.path;
        final arbFiles = Directory(projectRoot)
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.arb'))
            .toList();

        try {
          // Find the config file
          final configFile = findConfigFile(projectRoot);

          // Use the proper method with the correct parameters
          genArbCommand.genArb(projectRoot, configFile, arbFiles);

          print('ARB files generated successfully');
        } catch (e) {
          print('Error generating ARB files: $e');
          return 1;
        }
      } else {
        print('Export canceled. ARB files are required for export.');
        return 1;
      }
    }

    // Create target directory if it doesn't exist
    final targetDir = Directory(p.join('lib', 'l10n', target));
    if (!targetDir.existsSync()) {
      targetDir.createSync(recursive: true);
    }

    print('Exporting files with metadata support to $target format...');

    // Export files based on target format
    switch (target) {
      case 'xlf':
        await _exportToXliff(languages, baseLanguage, arbDir, targetDir);
        break;
    // Add other formats here as needed
      default:
        print('Unsupported export format: $target');
        return 1;
    }

    print('Successfully exported to ${targetDir.path} with descriptions and placeholder metadata');
    return 0;
  }

  bool _arbFilesExist(Directory arbDir, List<String> languages) {
    if (!arbDir.existsSync()) return false;

    // Check for both regular and metadata files
    final metadataDir = Directory(p.join(arbDir.path, 'metadata'));
    if (!metadataDir.existsSync()) return false;

    for (final lang in languages) {
      final arbFile = File(p.join(arbDir.path, 'app_$lang.arb'));
      final metadataFile = File(p.join(metadataDir.path, 'app_${lang}_metadata.arb'));
      if (!arbFile.existsSync() || !metadataFile.existsSync()) {
        return false;
      }
    }
    return true;
  }

  Future<void> _exportToXliff(List<String> languages, String baseLanguage, Directory sourceDir, Directory targetDir) async {
    // Load base language metadata ARB file for source text
    final baseLanguageFile = File(p.join(sourceDir.path, 'metadata', 'app_${baseLanguage}_metadata.arb'));
    if (!baseLanguageFile.existsSync()) {
      print('Warning: Base language metadata file not found. Using target language text as source.');
    }

    for (final lang in languages) {
      // Use metadata ARB file from the metadata subdirectory
      final arbFile = File(p.join(sourceDir.path, 'metadata', 'app_${lang}_metadata.arb'));
      if (arbFile.existsSync()) {
        // Pass the base language file if it exists and the current language isn't the base language
        final xliffContent = await ArbConverter.toXliff(
          arbFile,
          lang,
          baseLanguageFile: lang != baseLanguage ? baseLanguageFile : null,
          baseLanguage: baseLanguage, // Pass the base language code
        );
        final xliffFile = File(p.join(targetDir.path, 'app_$lang.xlf'));
        await xliffFile.writeAsString(xliffContent);
        print('Created ${xliffFile.path} with metadata preservation');
      } else {
        print('Warning: Metadata ARB file not found for language $lang');
      }
    }
  }
}