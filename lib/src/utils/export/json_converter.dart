import 'dart:convert';
import 'dart:io';

/// Converts ARB files to a simplified JSON format while preserving metadata
class JsonConverter {
  /// Converts ARB content to a JSON format suitable for translation
  Map<String, dynamic> convertToJson({
    required Map<String, dynamic> sourceContent,
    required Map<String, dynamic> targetContent,
  }) {
    final result = <String, dynamic>{
      'metadata': {
        'format_version': '1.0',
        'tool': 'gen_l10n_utils',
      },
      'translations': <String, dynamic>{},
    };

    for (final key in sourceContent.keys) {
      if (!key.startsWith('@')) {
        final metadata = sourceContent['@$key'] as Map<String, dynamic>?;
        final translation = <String, dynamic>{
          'source': sourceContent[key],
          if (targetContent.containsKey(key)) 'target': targetContent[key],
          if (metadata != null) ...{
            if (metadata['description'] != null)
              'description': metadata['description'],
            if (metadata['placeholders'] != null)
              'placeholders': metadata['placeholders'],
          },
        };

        result['translations'][key] = translation;
      }
    }

    return result;
  }

  /// Saves JSON content to a file with pretty printing
  void saveToFile(Map<String, dynamic> json, String outputPath) {
    final file = File(outputPath);
    final encoder = JsonEncoder.withIndent('  ');
    file.writeAsStringSync(encoder.convert(json));
  }
}
