import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:yaml_edit/yaml_edit.dart';
import 'package:gen_l10n_utils/src/utils/export/format_converter.dart';

class YamlConverter implements FormatConverter {
  @override
  void convert({
    required String baseLanguage,
    required List<String> languages,
    required String inputDir,
    required String outputDir,
  }) {
    final baseContent = _readArbFile(
      path.join(inputDir, 'metadata', 'app_${baseLanguage}_metadata.arb'),
    );

    // Convert other languages
    for (final language in languages) {
      if (language == baseLanguage) continue;

      final targetContent = _readArbFile(
        path.join(inputDir, 'metadata', 'app_${language}_metadata.arb'),
      );

      final yaml = convertToYaml(
        sourceLanguage: baseLanguage,
        targetLanguage: language,
        sourceContent: baseContent,
        targetContent: targetContent,
      );

      final outputPath = path.join(outputDir, 'yaml', 'app_$language.yaml');
      _ensureDirectoryExists(outputPath);
      saveToFile(yaml, outputPath);
    }
  }

  String convertToYaml({
    required String sourceLanguage,
    required String targetLanguage,
    required Map<String, dynamic> sourceContent,
    required Map<String, dynamic> targetContent,
  }) {
    final translations = <String, dynamic>{};

    _processTranslations(
      translations: translations,
      sourceContent: sourceContent,
      targetContent: targetContent,
    );

    final document = {
      'metadata': {
        'format_version': '1.0',
        'tool': 'gen_l10n_utils',
        'source_language': sourceLanguage,
        'target_language': targetLanguage,
      },
      'translations': translations,
    };

    final yamlEditor = YamlEditor('');
    yamlEditor.update([], document);
    return yamlEditor.toString();
  }

  void _processTranslations({
    required Map<String, dynamic> translations,
    required Map<String, dynamic> sourceContent,
    required Map<String, dynamic> targetContent,
    String prefix = '',
  }) {
    for (final key in sourceContent.keys) {
      if (!key.startsWith('@')) {
        final value = sourceContent[key];
        if (value is Map<String, dynamic>) {
          // Handle nested structures
          final nestedTranslations = <String, dynamic>{};
          _processTranslations(
            translations: nestedTranslations,
            sourceContent: value,
            targetContent: targetContent[key] ?? {},
            prefix: prefix.isEmpty ? key : '$prefix.$key',
          );
          translations[key] = nestedTranslations;
        } else {
          final metadataKey = '@$key';
          final metadata = sourceContent[metadataKey] as Map<String, dynamic>?;

          final targetMap = prefix.isEmpty
              ? targetContent
              : _getNestedValue(targetContent, prefix.split('.'));

          translations[key] = _createTranslationEntry(
            source: value as String,
            target: targetMap[key] as String?,
            metadata: metadata,
          );
        }
      }
    }
  }

  dynamic _getNestedValue(Map<String, dynamic> map, List<String> keys) {
    var current = map;
    for (var i = 0; i < keys.length; i++) {
      current = current[keys[i]] as Map<String, dynamic>? ?? {};
    }
    return current;
  }

  Map<String, dynamic> _createTranslationEntry({
    required String source,
    String? target,
    Map<String, dynamic>? metadata,
  }) {
    return {
      'source': source,
      'target': target ?? '',
      if (metadata != null) ...{
        if (metadata['description'] != null)
          'description': metadata['description'],
        if (metadata['placeholders'] != null)
          'placeholders': metadata['placeholders'],
      },
    };
  }

  void saveToFile(String yaml, String outputPath) {
    final file = File(outputPath);
    file.writeAsStringSync(yaml);
  }

  Map<String, dynamic> _readArbFile(String filePath) {
    final file = File(filePath);
    if (!file.existsSync()) {
      throw Exception('File not found: $filePath');
    }
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }

  void _ensureDirectoryExists(String filePath) {
    final directory = path.dirname(filePath);
    if (!Directory(directory).existsSync()) {
      Directory(directory).createSync(recursive: true);
    }
  }
}
