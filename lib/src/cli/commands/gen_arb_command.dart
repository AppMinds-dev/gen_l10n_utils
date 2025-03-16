import 'dart:io';
import 'dart:convert';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import 'package:gen_l10n_utils/src/utils/find_config_file.dart';
import 'package:gen_l10n_utils/src/utils/load_config.dart';

/// Result of ARB file merging with conflict information
class MergeResult {
  final Map<String, dynamic> content;
  final Map<String, List<ConflictEntry>> conflicts;

  MergeResult(this.content, this.conflicts);
}

/// Entry representing a key conflict
class ConflictEntry {
  final String filePath;
  final dynamic value;
  final dynamic existingValue;
  final String existingFilePath;

  ConflictEntry(
      this.filePath, this.value, this.existingValue, this.existingFilePath);
}

class GenArbCommand extends Command<int> {
  @override
  final name = 'gen-arb';
  @override
  final description =
      'Generates ARB files based on the localization configuration';

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
  void genArb(String projectRoot, File configFile, List<File> arbFiles,
      {File? mockOutputFile}) {
    try {
      final config = loadConfig(configFile);
      final supportedLanguages = config['languages'] as List<String>;

      final outputDir = Directory(p.join(projectRoot, 'lib/l10n'));
      if (!outputDir.existsSync()) {
        outputDir.createSync(recursive: true);
      }

      final Map<String, List<File>> languageFiles = {
        for (var lang in supportedLanguages) lang: []
      };

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
        throw Exception(
            '❌ No .arb files found for supported languages. Ensure your .arb files are in language-specific directories (e.g., /lib/*/l10n/en/*.arb).');
      }

      for (final lang in supportedLanguages) {
        if (languageFiles[lang]!.isNotEmpty) {
          final result =
              mergeArbFilesWithConflictDetection(languageFiles[lang]!);
          final mergedContent = result.content;

          // Sort the keys alphabetically
          final sortedContent = _sortMapByKeys(mergedContent);

          final outputFile =
              mockOutputFile ?? File(p.join(outputDir.path, 'app_$lang.arb'));

          outputFile.writeAsStringSync(
            const JsonEncoder.withIndent("  ").convert(sortedContent),
          );

          print(
              '✅ Translations merged: ${languageFiles[lang]!.length} files for "$lang" → ${outputFile.path}');

          // Report conflicts for this language
          if (result.conflicts.isNotEmpty) {
            reportConflicts(result.conflicts, lang);
          }
        } else {
          print('⚠️ Warning: No .arb files found for language "$lang"');
        }
      }
    } catch (e) {
      throw Exception('❌ Error during translation merging: $e');
    }
  }

  /// Merges multiple .arb files into a single JSON structure with flattened keys
  /// and detects conflicts
  MergeResult mergeArbFilesWithConflictDetection(List<File> arbFiles) {
    final mergedContent = <String, dynamic>{};
    final conflicts = <String, List<ConflictEntry>>{};
    final keySourceFiles = <String, String>{}; // Track where each key came from

    for (final file in arbFiles) {
      final content = file.readAsStringSync();
      try {
        final jsonContent = jsonDecode(content) as Map<String, dynamic>;
        final flattened = flattenJson(jsonContent);

        // Check for conflicts while merging
        for (final entry in flattened.entries) {
          final key = entry.key;
          final value = entry.value;

          if (mergedContent.containsKey(key)) {
            // If the key already exists with a different value
            if (mergedContent[key] != value) {
              // Track conflict
              conflicts.putIfAbsent(key, () => []).add(
                    ConflictEntry(
                      file.path,
                      value,
                      mergedContent[key],
                      keySourceFiles[key] ?? 'unknown source',
                    ),
                  );
              // First occurrence wins (don't overwrite)
              continue;
            }
          } else {
            // Store the source file for this key for later conflict reporting
            keySourceFiles[key] = file.path;
          }

          // Add entry (only if it doesn't exist yet or has the same value)
          mergedContent[key] = value;
        }
      } catch (e) {
        throw Exception('❌ Error parsing ${file.path}: $e');
      }
    }

    return MergeResult(mergedContent, conflicts);
  }

  /// Report conflicts to the user
  void reportConflicts(
      Map<String, List<ConflictEntry>> conflicts, String language) {
    print(
        '\n⚠️ Warning: Found ${conflicts.length} key conflicts in $language files:');

    for (var key in conflicts.keys) {
      print('  Key "$key" has conflicts:');
      final firstConflict = conflicts[key]![0];
      print(
          '    Used value: "${firstConflict.existingValue}" from ${firstConflict.existingFilePath}');

      for (var conflict in conflicts[key]!) {
        print(
            '    Ignored value: "${conflict.value}" from ${conflict.filePath}');
      }
    }

    print('\nFirst occurrence of each key was used in the merged files.\n');
  }

  /// Merges multiple .arb files into a single JSON structure with flattened keys
  /// Legacy method kept for backward compatibility
  Map<String, dynamic> mergeArbFiles(List<File> arbFiles) {
    return mergeArbFilesWithConflictDetection(arbFiles).content;
  }

  /// Flattens nested JSON objects into dot notation
  Map<String, dynamic> flattenJson(Map<String, dynamic> json,
      {String prefix = ''}) {
    final result = <String, dynamic>{};

    json.forEach((key, value) {
      final newKey = prefix.isEmpty ? key : '$prefix.$key';

      if (value is Map<String, dynamic>) {
        // Recursively flatten nested objects
        result.addAll(flattenJson(value, prefix: newKey));
      } else {
        // Add leaf nodes directly
        result[newKey] = value;
      }
    });

    return result;
  }

  /// Sorts a map by its keys alphabetically
  Map<String, dynamic> _sortMapByKeys(Map<String, dynamic> map) {
    final sortedKeys = map.keys.toList()..sort();
    final sortedMap = <String, dynamic>{};

    for (var key in sortedKeys) {
      sortedMap[key] = map[key];
    }

    return sortedMap;
  }
}
