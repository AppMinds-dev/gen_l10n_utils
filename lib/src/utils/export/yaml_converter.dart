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

    for (final language in languages) {
      if (language == baseLanguage) continue;

      final targetContent = _readArbFile(
        path.join(inputDir, 'metadata', 'app_${language}_metadata.arb'),
      );

      final yaml = convertToYaml(
        sourceContent: baseContent,
        targetContent: targetContent,
      );

      final outputPath = path.join(outputDir, 'yaml', 'app_$language.yaml');
      _ensureDirectoryExists(outputPath);
      saveToFile(yaml, outputPath);
    }
  }

  /// Converts ARB content to YAML format
  String convertToYaml({
    required Map<String, dynamic> sourceContent,
    required Map<String, dynamic> targetContent,
  }) {
    final translations = <String, dynamic>{};

    // Process each translation entry
    for (final key in sourceContent.keys) {
      if (!key.startsWith('@')) {
        final metadata = sourceContent['@$key'] as Map<String, dynamic>?;
        final source = sourceContent[key] as String;
        final target = targetContent[key] as String?;

        translations[key] = _createTranslationEntry(
          source: source,
          target: target,
          metadata: metadata,
        );
      }
    }

    final document = {
      'metadata': {
        'format_version': '1.0',
        'tool': 'gen_l10n_utils',
      },
      'translations': translations,
    };

    final yamlEditor = YamlEditor('');
    yamlEditor.update([], document);
    return yamlEditor.toString();
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

  /// Saves YAML content to a file
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
