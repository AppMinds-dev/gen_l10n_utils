import 'dart:io';
import 'dart:convert';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import 'package:appminds_l10n_tools/src/utils/find_config_file.dart';
import 'package:appminds_l10n_tools/src/utils/load_config.dart';

class GenArbCommand extends Command<int> {
  @override
  final name = 'gen-arb';
  @override
  final description = 'Generates ARB files based on the localization configuration';

  @override
  Future<int> run() async {
    final currentDir = Directory.current.path;

    try {
      final configFilePath = findConfigFile(currentDir);

      // Find ARB files
      final arbFiles = Directory(currentDir)
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.arb'))
          .toList();

      try {
        genArb(currentDir, configFilePath, arbFiles);
        return 0;
      } catch (e) {
        stderr.writeln(e.toString());
        return 1;
      }
    } catch (e) {
      stderr.writeln('❌ Error: ${e.toString()}');
      return 1;
    }
  }

  /// Generates merged ARB files for supported languages
  void genArb(String projectRoot, File configFile, List<File> arbFiles, {File? mockOutputFile}) {
    try {
      final config = loadConfig(configFile);
      final supportedLanguages = config['languages'] as List<String>;

      final outputDir = Directory(p.join(projectRoot, 'lib/l10n'));
      if (!outputDir.existsSync()) {
        outputDir.createSync(recursive: true);
      }

      final Map<String, List<File>> languageFiles = {for (var lang in supportedLanguages) lang: []};

      // Revised language detection - check directory path instead of filename
      for (final file in arbFiles) {
        // Split the path and look for language directory
        final pathSegments = p.split(file.path);

        // Find if any path segment matches a supported language
        for (final lang in supportedLanguages) {
          if (pathSegments.contains(lang)) {
            languageFiles[lang]!.add(file);
            // Once we've found a match, move to the next file
            break;
          }
        }
      }

      if (languageFiles.values.every((files) => files.isEmpty)) {
        throw Exception('❌ No .arb files found for supported languages. Ensure your .arb files are in language-specific directories (e.g., /lib/*/l10n/en/*.arb).');
      }

      for (final lang in supportedLanguages) {
        if (languageFiles[lang]!.isNotEmpty) {
          final mergedContent = mergeArbFiles(languageFiles[lang]!);
          final outputFile = mockOutputFile ?? File(p.join(outputDir.path, 'app_$lang.arb'));

          outputFile.writeAsStringSync(
            const JsonEncoder.withIndent("  ").convert(mergedContent),
          );

          print('✅ Translations merged: ${languageFiles[lang]!.length} files for "$lang" → ${outputFile.path}');
        } else {
          print('⚠️ Warning: No .arb files found for language "$lang"');
        }
      }
    } catch (e) {
      throw Exception('❌ Error during translation merging: $e');
    }
  }

  /// Deep merges JSON objects
  Map<String, dynamic> deepMerge(Map<String, dynamic> base, Map<String, dynamic> updates) {
    for (final key in updates.keys) {
      if (base.containsKey(key) && base[key] is Map && updates[key] is Map) {
        base[key] = deepMerge(
          Map<String, dynamic>.from(base[key]),
          Map<String, dynamic>.from(updates[key]),
        );
      } else {
        base[key] = updates[key];
      }
    }
    return base;
  }

  /// Merges multiple .arb files into a single JSON structure
  Map<String, dynamic> mergeArbFiles(List<File> arbFiles) {
    final mergedContent = <String, dynamic>{};

    for (final file in arbFiles) {
      final content = file.readAsStringSync();
      try {
        final jsonContent = jsonDecode(content) as Map<String, dynamic>;
        deepMerge(mergedContent, jsonContent);
      } catch (e) {
        throw Exception('❌ Error parsing ${file.path}: $e');
      }
    }

    return mergedContent;
  }
}