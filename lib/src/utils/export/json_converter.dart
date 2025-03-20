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

    // Convert other languages
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
        final metadataKey = '@$key';
        final metadata = sourceContent[metadataKey] as Map<String, dynamic>?;

        final source = sourceContent[key];
        final target = targetContent[key];

        if (source is Map<String, dynamic>) {
          // Handle nested structures
          translations[key] = _createNestedTranslationEntry(
            source: source,
            target: target as Map<String, dynamic>?,
            metadata: metadata,
          );
        } else {
          // Handle simple string translations
          translations[key] = _createTranslationEntry(
            source: source as String,
            target: target as String?,
            metadata: metadata,
          );
        }
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

  Map<String, dynamic> _createNestedTranslationEntry({
    required Map<String, dynamic> source,
    Map<String, dynamic>? target,
    Map<String, dynamic>? metadata,
  }) {
    final nestedTranslations = <String, dynamic>{};

    source.forEach((key, sourceValue) {
      if (!key.startsWith('@')) {
        final nestedMetadataKey = '@$key';
        final nestedMetadata =
            source[nestedMetadataKey] as Map<String, dynamic>?;

        if (sourceValue is Map<String, dynamic>) {
          nestedTranslations[key] = _createNestedTranslationEntry(
            source: sourceValue,
            target: target?[key] as Map<String, dynamic>?,
            metadata: nestedMetadata,
          );
        } else {
          nestedTranslations[key] = _createTranslationEntry(
            source: sourceValue as String,
            target: target?[key] as String?,
            metadata: nestedMetadata,
          );
        }
      }
    });

    return {
      'translations': nestedTranslations,
      if (metadata != null) ...{
        if (metadata['description'] != null)
          'description': metadata['description'],
      },
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
