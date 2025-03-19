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

  /// Converts ARB content to PO format
  String convertToPo({
    required String sourceLanguage,
    required String targetLanguage,
    required Map<String, dynamic> sourceContent,
    required Map<String, dynamic> targetContent,
  }) {
    final buffer = StringBuffer();

    // Write PO header
    _writeHeader(buffer, targetLanguage);

    // Process each translation entry
    for (final key in sourceContent.keys) {
      if (!key.startsWith('@')) {
        final metadata = sourceContent['@$key'] as Map<String, dynamic>?;
        final source = sourceContent[key] as String;
        final target = targetContent[key] as String?;

        _writeEntry(
          buffer,
          key: key,
          source: source,
          target: target,
          metadata: metadata,
        );
      }
    }

    return buffer.toString();
  }

  void _writeHeader(StringBuffer buffer, String language) {
    buffer.writeln('msgid ""');
    buffer.writeln('msgstr ""');
    buffer.writeln('"Project-Id-Version: gen_l10n_utils\\n"');
    buffer.writeln('"Report-Msgid-Bugs-To: \\n"');
    buffer
        .writeln('"POT-Creation-Date: ${DateTime.now().toIso8601String()}\\n"');
    buffer
        .writeln('"PO-Revision-Date: ${DateTime.now().toIso8601String()}\\n"');
    buffer.writeln('"Last-Translator: gen_l10n_utils\\n"');
    buffer.writeln('"Language-Team: none\\n"');
    buffer.writeln('"Language: $language\\n"');
    buffer.writeln('"MIME-Version: 1.0\\n"');
    buffer.writeln('"Content-Type: text/plain; charset=UTF-8\\n"');
    buffer.writeln('"Content-Transfer-Encoding: 8bit\\n"');
    buffer.writeln('"Plural-Forms: nplurals=2; plural=(n != 1);\\n"');
    buffer.writeln();
  }

  void _writeEntry(
    StringBuffer buffer, {
    required String key,
    required String source,
    String? target,
    Map<String, dynamic>? metadata,
  }) {
    buffer.writeln();

    // Write comments
    if (metadata != null) {
      // Description as translator comments
      final description = metadata['description'] as String?;
      if (description != null && description.isNotEmpty) {
        buffer.writeln('# $description');
      }

      // Placeholder information as extracted comments
      final placeholders = metadata['placeholders'] as Map<String, dynamic>?;
      if (placeholders != null) {
        for (final placeholder in placeholders.entries) {
          final name = placeholder.key;
          final props = placeholder.value as Map<String, dynamic>;

          buffer.writeln('#. Placeholder: $name');
          if (props['type'] != null) {
            buffer.writeln('#. Type: ${props['type']}');
          }
          if (props['example'] != null) {
            buffer.writeln('#. Example: ${props['example']}');
          }
          if (props['description'] != null) {
            buffer.writeln('#. Description: ${props['description']}');
          }
        }
      }
    }

    // Reference comment (location)
    buffer.writeln('#: $key');

    // Message context (optional, used for disambiguation)
    buffer.writeln('msgctxt "$key"');

    // Source string
    buffer.writeln('msgid "${_escapePo(source)}"');

    // Target string (translation)
    buffer.writeln('msgstr "${_escapePo(target ?? '')}"');
  }

  String _escapePo(String text) {
    return text
        .replaceAll('"', '\\"')
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r')
        .replaceAll('\t', '\\t');
  }

  /// Saves PO content to a file
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
