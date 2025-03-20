import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:gen_l10n_utils/src/utils/export/format_converter.dart';

class CsvConverter implements FormatConverter {
  static const String _delimiter = ',';
  static const String _quote = '"';
  static const String _escape = '""';

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

      final csvContent = convertToCsv(
        sourceLanguage: baseLanguage,
        targetLanguage: language,
        sourceContent: baseContent,
        targetContent: targetContent,
      );

      final outputPath = path.join(outputDir, 'csv', 'app_$language.csv');
      _ensureDirectoryExists(outputPath);
      saveToFile(csvContent, outputPath);
    }
  }

  /// Converts ARB content to CSV format
  String convertToCsv({
    required String sourceLanguage,
    required String targetLanguage,
    required Map<String, dynamic> sourceContent,
    required Map<String, dynamic> targetContent,
  }) {
    final StringBuffer buffer = StringBuffer();

    // Write header row
    buffer.writeln(_escapeCsvRow([
      'Key',
      'Source ($sourceLanguage)',
      'Target ($targetLanguage)',
      'Description',
      'Placeholder',
      'Placeholder Details'
    ]));

    // Process all translation keys
    for (final key in sourceContent.keys) {
      if (!key.startsWith('@')) {
        final metadata = sourceContent['@$key'] as Map<String, dynamic>?;
        final description = metadata?['description'] as String?;
        final placeholders = metadata?['placeholders'] as Map<String, dynamic>?;

        if (placeholders != null && placeholders.isNotEmpty) {
          // Write a row for each placeholder
          for (final placeholder in placeholders.entries) {
            final details = [
              if (placeholder.value['type'] != null)
                'Type: ${placeholder.value['type']}',
              if (placeholder.value['example'] != null)
                'Example: ${placeholder.value['example']}',
              if (placeholder.value['description'] != null)
                'Description: ${placeholder.value['description']}',
            ].join('; ');

            buffer.writeln(_escapeCsvRow([
              key,
              sourceContent[key] as String,
              targetContent[key] as String? ?? '',
              description ?? '',
              placeholder.key,
              details
            ]));
          }
        } else {
          // Write a row without placeholder details
          buffer.writeln(_escapeCsvRow([
            key,
            sourceContent[key] as String,
            targetContent[key] as String? ?? '',
            description ?? '',
            '',
            ''
          ]));
        }
      }
    }

    return buffer.toString();
  }

  /// Escapes and formats a list of values as a CSV row
  String _escapeCsvRow(List<String> values) {
    return values.map((value) => _escapeCsvValue(value)).join(_delimiter);
  }

  /// Escapes a single CSV value
  String _escapeCsvValue(String value) {
    // If the value contains a delimiter, newline, or quote, wrap it in quotes and escape quotes
    if (value.contains(_delimiter) ||
        value.contains('\n') ||
        value.contains('\r') ||
        value.contains(_quote)) {
      return '$_quote${value.replaceAll(_quote, _escape)}$_quote';
    }
    return value;
  }

  /// Saves CSV content to a file
  void saveToFile(String csvContent, String outputPath) {
    final file = File(outputPath);
    file.writeAsStringSync(csvContent);
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
