import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:gen_l10n_utils/src/utils/export/format_converter.dart';

class PoConverter implements FormatConverter {
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

      final po = convertToPo(
        sourceLanguage: baseLanguage,
        targetLanguage: language,
        sourceContent: baseContent,
        targetContent: targetContent,
      );

      final outputPath = path.join(outputDir, 'po', 'app_$language.po');
      _ensureDirectoryExists(outputPath);
      saveToFile(po, outputPath);
    }
  }

  String convertToPo({
    required String sourceLanguage,
    required String targetLanguage,
    required Map<String, dynamic> sourceContent,
    required Map<String, dynamic> targetContent,
  }) {
    final buffer = StringBuffer();

    // Write PO header
    buffer.writeln('msgid ""');
    buffer.writeln('msgstr ""');
    buffer.writeln('"Project-Id-Version: 1.0\\n"');
    buffer.writeln('"Content-Type: text/plain; charset=UTF-8\\n"');
    buffer.writeln('"Language: $targetLanguage\\n"');
    buffer.writeln('"Source-Language: $sourceLanguage\\n"');
    buffer.writeln('"Plural-Forms: nplurals=2; plural=(n != 1);\\n"');
    buffer.writeln();

    _processTranslations(
      buffer: buffer,
      sourceContent: sourceContent,
      targetContent: targetContent,
    );

    return buffer.toString();
  }

  void _processTranslations({
    required StringBuffer buffer,
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
            buffer: buffer,
            sourceContent: value,
            targetContent: targetContent[key] ?? {},
            prefix: prefix.isEmpty ? key : '$prefix.$key',
          );
        } else {
          final fullKey = prefix.isEmpty ? key : '$prefix.$key';
          final metadataKey = '@$key';
          final metadata = sourceContent[metadataKey] as Map<String, dynamic>?;

          // Write reference first
          buffer.writeln('#: $fullKey');

          // Write translator comments
          if (metadata?['description'] != null) {
            buffer.writeln('#, ${metadata!['description']}');
          }

          // Write placeholder information if present
          if (metadata?['placeholders'] != null) {
            final placeholders =
                metadata!['placeholders'] as Map<String, dynamic>;
            final placeholderComments = placeholders.entries.map((placeholder) {
              final details = <String>[];
              if (placeholder.value['type'] != null) {
                details.add('type: ${placeholder.value['type']}');
              }
              if (placeholder.value['example'] != null) {
                details.add('example: ${placeholder.value['example']}');
              }
              if (placeholder.value['description'] != null) {
                details.add('desc: ${placeholder.value['description']}');
              }
              return '${placeholder.key} (${details.join(', ')})';
            }).join('; ');

            if (placeholderComments.isNotEmpty) {
              buffer.writeln('#| placeholders: $placeholderComments');
            }
          }

          // Write message ID and translation
          final targetMap = prefix.isEmpty
              ? targetContent
              : _getNestedValue(targetContent, prefix.split('.'));

          buffer.writeln('msgid "${_escapePo(value as String)}"');
          buffer.writeln(
              'msgstr "${_escapePo(targetMap?[key] as String? ?? '')}"');
          buffer.writeln();
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

  String _escapePo(String text) {
    return text
        .replaceAll('\\', '\\\\')
        .replaceAll('"', '\\"')
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r');
  }

  void saveToFile(String content, String outputPath) {
    final file = File(outputPath);
    file.writeAsStringSync(content);
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
