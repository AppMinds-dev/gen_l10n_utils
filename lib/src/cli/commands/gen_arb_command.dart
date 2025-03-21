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
  final Map<String, dynamic> originalContent;

  MergeResult(this.content, this.conflicts, this.originalContent);
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

  static const configFileName = 'gen_l10n_utils.yaml';

  @override
  Future<int> run() async {
    final currentDir = Directory.current.path;

    try {
      // Try to find the config file first
      File? configFile;
      try {
        configFile = findConfigFile(currentDir);
      } catch (e) {
        stderr.writeln(
            '❌  Error: Configuration file $configFileName not found. Run create-config command first.');
        return 1;
      }

      // Find ARB files
      final arbFiles = Directory(currentDir)
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.arb'))
          .toList();

      try {
        genArb(currentDir, configFile, arbFiles);
        return 0;
      } catch (e) {
        stderr.writeln(e.toString());
        return 1;
      }
    } catch (e) {
      stderr.writeln('❌  Error: ${e.toString()}');
      return 1;
    }
  }

  void genArb(String projectRoot, File configFile, List<File> arbFiles,
      {File? mockOutputFile}) {
    try {
      final config = loadConfig(configFile);
      final supportedLanguages = config['languages'] as List<String>;

      final outputDir = Directory(p.join(projectRoot, 'lib/l10n'));
      if (!outputDir.existsSync()) {
        outputDir.createSync(recursive: true);
      }

      final metadataDir = Directory(p.join(outputDir.path, 'metadata'));
      if (!metadataDir.existsSync()) {
        metadataDir.createSync(recursive: true);
      }

      final Map<String, List<File>> languageFiles = {
        for (var lang in supportedLanguages) lang: []
      };

      for (final file in arbFiles) {
        final pathSegments = p.split(file.path);
        for (final lang in supportedLanguages) {
          if (pathSegments.contains(lang)) {
            languageFiles[lang]!.add(file);
            break;
          }
        }
      }

      if (languageFiles.values.every((files) => files.isEmpty)) {
        throw Exception(
            '❌  No .arb files found for supported languages. Ensure your .arb files are in language-specific directories (e.g., /lib/*/l10n/en/*.arb).');
      }

      for (final lang in supportedLanguages) {
        if (languageFiles[lang]!.isNotEmpty) {
          final result =
              mergeArbFilesWithConflictDetection(languageFiles[lang]!);

          // Generate simplified version (just translations)
          var simplifiedContent = _createSimplifiedArb(result.content);
          // Transform keys to replace '.' with '_'
          simplifiedContent = _transformKeys(simplifiedContent);
          final sortedSimplified = _sortMapByKeys(simplifiedContent);

          // Generate metadata version
          final metadataContent = _createMetadataArb(result.originalContent);
          final sortedMetadata = _sortMapByKeys(metadataContent);

          // Write simplified version
          final outputFile =
              mockOutputFile ?? File(p.join(outputDir.path, 'app_$lang.arb'));
          outputFile.writeAsStringSync(
            const JsonEncoder.withIndent("  ").convert(sortedSimplified),
          );

          // Write metadata version
          final metadataFile =
              File(p.join(metadataDir.path, 'app_${lang}_metadata.arb'));
          metadataFile.writeAsStringSync(
            const JsonEncoder.withIndent("  ").convert(sortedMetadata),
          );

          print('✅  Generated files for "$lang":');
          print('   → ${outputFile.path} (simplified)');
          print('   → ${metadataFile.path} (with metadata)');

          if (result.conflicts.isNotEmpty) {
            reportConflicts(result.conflicts, lang);
          }
        } else {
          print('⚠️  Warning: No .arb files found for language "$lang"');
        }
      }
    } catch (e) {
      throw Exception('❌  Error during translation merging: $e');
    }
  }

  Map<String, dynamic> _createSimplifiedArb(Map<String, dynamic> content) {
    final simplified = <String, dynamic>{};
    content.forEach((key, value) {
      if (!key.startsWith('@')) {
        simplified[key] = value;
      }
    });
    return simplified;
  }

  Map<String, dynamic> _createMetadataArb(Map<String, dynamic> content) {
    final metadata = <String, dynamic>{};
    content.forEach((key, value) {
      metadata[key] = value;
    });
    return metadata;
  }

  MergeResult mergeArbFilesWithConflictDetection(List<File> arbFiles) {
    final mergedContent = <String, dynamic>{};
    final originalContent = <String, dynamic>{};
    final conflicts = <String, List<ConflictEntry>>{};
    final keySourceFiles = <String, String>{};

    for (final file in arbFiles) {
      final content = file.readAsStringSync();
      try {
        final jsonContent = jsonDecode(content) as Map<String, dynamic>;

        // Store the original unflattened content for metadata
        jsonContent.forEach((key, value) {
          if (!originalContent.containsKey(key)) {
            originalContent[key] = value;
          }
        });

        // Process flattened content for simplified version
        final flattened = flattenJson(jsonContent);

        for (final entry in flattened.entries) {
          final key = entry.key;
          final value = entry.value;

          if (mergedContent.containsKey(key)) {
            if (mergedContent[key] != value) {
              conflicts.putIfAbsent(key, () => []).add(
                    ConflictEntry(
                      file.path,
                      value,
                      mergedContent[key],
                      keySourceFiles[key] ?? 'unknown source',
                    ),
                  );
              continue;
            }
          } else {
            keySourceFiles[key] = file.path;
          }

          mergedContent[key] = value;
        }
      } catch (e) {
        throw Exception('❌  Error parsing ${file.path}: $e');
      }
    }

    return MergeResult(mergedContent, conflicts, originalContent);
  }

  void reportConflicts(
      Map<String, List<ConflictEntry>> conflicts, String language) {
    print(
        '\n⚠️  Warning: Found ${conflicts.length} key conflicts in $language files:');

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

  Map<String, dynamic> mergeArbFiles(List<File> arbFiles) {
    return mergeArbFilesWithConflictDetection(arbFiles).content;
  }

  Map<String, dynamic> flattenJson(Map<String, dynamic> json,
      {String prefix = ''}) {
    final result = <String, dynamic>{};

    json.forEach((key, value) {
      final newKey = prefix.isEmpty ? key : '$prefix.$key';

      if (value is Map<String, dynamic>) {
        result.addAll(flattenJson(value, prefix: newKey));
      } else {
        result[newKey] = value;
      }
    });

    return result;
  }

  Map<String, dynamic> _sortMapByKeys(Map<String, dynamic> map) {
    final sortedKeys = map.keys.toList()..sort();
    final sortedMap = <String, dynamic>{};

    for (var key in sortedKeys) {
      sortedMap[key] = map[key];
    }

    return sortedMap;
  }

  Map<String, dynamic> _transformKeys(Map<String, dynamic> map) {
    final transformedMap = <String, dynamic>{};
    map.forEach((key, value) {
      final newKey = key.replaceAll('.', '_');
      transformedMap[newKey] = value;
    });
    return transformedMap;
  }
}
