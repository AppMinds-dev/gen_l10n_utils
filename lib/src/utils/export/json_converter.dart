import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:gen_l10n_utils/src/utils/export/format_converter.dart';

class JsonConverter implements FormatConverter {
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

      final json = convertToJson(
        sourceContent: baseContent,
        targetContent: targetContent,
      );

      final outputPath = path.join(outputDir, 'json', 'app_$language.json');
      _ensureDirectoryExists(outputPath);
      saveToFile(json, outputPath);
    }
  }

  /// Converts ARB content to JSON format
  Map<String, dynamic> convertToJson({
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

    return {
      'metadata': {
        'format_version': '1.0',
        'tool': 'gen_l10n_utils',
      },
      'translations': translations,
    };
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

  /// Saves JSON content to a file
  void saveToFile(Map<String, dynamic> json, String outputPath) {
    final file = File(outputPath);
    file.writeAsStringSync(
      JsonEncoder.withIndent('  ').convert(json),
    );
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
