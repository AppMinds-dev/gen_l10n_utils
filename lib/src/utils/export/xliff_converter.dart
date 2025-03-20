import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:xml/xml.dart';
import 'package:gen_l10n_utils/src/utils/export/format_converter.dart';

class XliffConverter implements FormatConverter {
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

      final xliff = convertToXliff(
        sourceLanguage: baseLanguage,
        targetLanguage: language,
        sourceContent: baseContent,
        targetContent: targetContent,
      );

      final outputPath = path.join(outputDir, 'xlf', 'app_$language.xlf');
      _ensureDirectoryExists(outputPath);
      saveToFile(xliff, outputPath);
    }
  }

  XmlDocument convertToXliff({
    required String sourceLanguage,
    required String targetLanguage,
    required Map<String, dynamic> sourceContent,
    required Map<String, dynamic> targetContent,
  }) {
    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');

    builder.element('xliff', attributes: {
      'version': '1.2',
      'xmlns': 'urn:oasis:names:tc:xliff:document:1.2',
    }, nest: () {
      builder.element('file', attributes: {
        'source-language': sourceLanguage,
        'target-language': targetLanguage,
        'datatype': 'plaintext',
        'original': 'messages',
      }, nest: () {
        _buildHeader(builder);
        _buildBody(
          builder,
          sourceContent: sourceContent,
          targetContent: targetContent,
        );
      });
    });

    return builder.buildDocument();
  }

  void _buildHeader(XmlBuilder builder) {
    builder.element('header', nest: () {
      builder.element('tool', attributes: {
        'tool-id': 'gen_l10n_utils',
        'tool-name': 'gen_l10n_utils',
      });
    });
  }

  void _buildBody(
    XmlBuilder builder, {
    required Map<String, dynamic> sourceContent,
    required Map<String, dynamic> targetContent,
  }) {
    builder.element('body', nest: () {
      _processTranslations(
        builder: builder,
        sourceContent: sourceContent,
        targetContent: targetContent,
      );
    });
  }

  void _processTranslations({
    required XmlBuilder builder,
    required Map<String, dynamic> sourceContent,
    required Map<String, dynamic> targetContent,
    String prefix = '',
  }) {
    for (final key in sourceContent.keys) {
      if (!key.startsWith('@')) {
        final value = sourceContent[key];
        if (value is Map<String, dynamic>) {
          // Handle nested structures
          _processTranslations(
            builder: builder,
            sourceContent: value,
            targetContent: targetContent[key] ?? {},
            prefix: prefix.isEmpty ? key : '$prefix.$key',
          );
        } else {
          final fullKey = prefix.isEmpty ? key : '$prefix.$key';
          final metadataKey = '@$key';
          final metadata = sourceContent[metadataKey] as Map<String, dynamic>?;

          final targetMap = prefix.isEmpty
              ? targetContent
              : _getNestedValue(targetContent, prefix.split('.'));

          _buildTransUnit(
            builder,
            id: fullKey,
            source: value as String,
            target: targetMap?[key] as String?,
            metadata: metadata,
          );
        }
      }
    }
  }

  void _buildTransUnit(
    XmlBuilder builder, {
    required String id,
    required String source,
    String? target,
    Map<String, dynamic>? metadata,
  }) {
    builder.element('trans-unit', attributes: {'id': id}, nest: () {
      builder.element('source', nest: source);
      builder.element('target', nest: target ?? '');

      if (metadata != null) {
        final description = metadata['description'] as String?;
        if (description != null && description.isNotEmpty) {
          builder.element('note', nest: description);
        }

        final placeholders = metadata['placeholders'] as Map<String, dynamic>?;
        if (placeholders != null) {
          for (final placeholder in placeholders.entries) {
            final name = placeholder.key;
            final props = placeholder.value as Map<String, dynamic>;
            final note = [
              if (props['type'] != null) 'type: ${props['type']}',
              if (props['example'] != null) 'example: ${props['example']}',
              if (props['description'] != null) 'desc: ${props['description']}',
            ].join(', ');

            if (note.isNotEmpty) {
              builder.element('note',
                  attributes: {'from': 'placeholder', 'name': name},
                  nest: note);
            }
          }
        }
      }
    });
  }

  dynamic _getNestedValue(Map<String, dynamic> map, List<String> keys) {
    var current = map;
    for (var i = 0; i < keys.length; i++) {
      current = current[keys[i]] as Map<String, dynamic>? ?? {};
    }
    return current;
  }

  void saveToFile(XmlDocument xliff, String outputPath) {
    final file = File(outputPath);
    file.writeAsStringSync(xliff.toXmlString(pretty: true));
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
