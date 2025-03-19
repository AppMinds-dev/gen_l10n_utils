// lib/src/utils/arb_converter.dart
import 'dart:convert';
import 'dart:io';

import 'package:xml/xml.dart';

class ArbConverter {
  /// Converts an ARB file to XLIFF format including metadata
  static Future<String> toXliff(
      File arbFile,
      String language, {
        File? baseLanguageFile,
        String baseLanguage = 'en',
      }) async {
    final content = await arbFile.readAsString();
    final Map<String, dynamic> arbJson = jsonDecode(content);

    // Debug: Print the ARB content to see if metadata exists
    print('ARB file for $language contains metadata: ${arbJson.keys.any((k) => k.startsWith('@'))}');
    if (arbJson.keys.any((k) => k.startsWith('@'))) {
      final metadataKeys = arbJson.keys.where((k) => k.startsWith('@')).toList();
      print('Metadata keys found: $metadataKeys');
      // Print a sample metadata entry
      if (metadataKeys.isNotEmpty) {
        final sampleKey = metadataKeys.first;
        print('Sample metadata for $sampleKey: ${arbJson[sampleKey]}');
      }
    }

    // Load base language content if provided (for source text)
    Map<String, dynamic>? baseLanguageJson;
    if (baseLanguageFile != null && baseLanguageFile.existsSync()) {
      final baseContent = await baseLanguageFile.readAsString();
      baseLanguageJson = jsonDecode(baseContent);
    }

    // Create XLIFF document
    final builder = XmlBuilder();
    builder.declaration(encoding: 'UTF-8');
    builder.element('xliff', attributes: {
      'version': '1.2',
      'xmlns': 'urn:oasis:names:tc:xliff:document:1.2',
    }, nest: () {
      builder.element('file', attributes: {
        'source-language': baseLanguage,
        'target-language': language,
        'datatype': 'plaintext',
        'original': 'messages',
      }, nest: () {
        builder.element('header', nest: () {
          builder.element('tool', attributes: {
            'tool-id': 'gen_l10n_utils',
            'tool-name': 'gen_l10n_utils',
          });
        });

        builder.element('body', nest: () {
          // Process translation keys (those that don't start with @)
          final translationKeys = arbJson.keys
              .where((key) => !key.startsWith('@') && arbJson[key] is String)
              .toList()
            ..sort();

          for (final key in translationKeys) {
            final value = arbJson[key];
            final metadataKey = '@$key';
            final metadata = arbJson[metadataKey];

            // Debug: Print metadata for this key if available
            if (metadata != null) {
              print('Processing key $key with metadata: $metadata');
            } else {
              print('Processing key $key with NO metadata found');
            }

            // Get source text from base language file if available
            String sourceText = value.toString();
            if (baseLanguageJson != null && baseLanguageJson.containsKey(key)) {
              sourceText = baseLanguageJson[key].toString();
            }

            builder.element('trans-unit', attributes: {'id': key}, nest: () {
              // Source text
              builder.element('source', nest: sourceText);

              // Target text
              builder.element('target', nest: value.toString());

              // Add description if available
              if (metadata != null && metadata['description'] != null) {
                builder.element('note', attributes: {'priority': '1'},
                    nest: metadata['description'].toString());
                print('Added description for $key: ${metadata['description']}');
              }

              // Add placeholders if available
              if (metadata != null && metadata['placeholders'] != null) {
                final placeholders = metadata['placeholders'] as Map<String, dynamic>;
                print('Adding ${placeholders.length} placeholders for $key');

                placeholders.forEach((phName, phData) {
                  builder.element('note', attributes: {
                    'from': 'placeholder',
                    'name': phName,
                  }, nest: () {
                    final details = <String>[];

                    if (phData['type'] != null) {
                      details.add('Type: ${phData['type']}');
                    }
                    if (phData['example'] != null) {
                      details.add('Example: ${phData['example']}');
                    }
                    if (phData['description'] != null) {
                      details.add('Description: ${phData['description']}');
                    }

                    builder.text(details.join(', '));
                  });
                });
              }
            });
          }
        });
      });
    });

    return builder.buildDocument().toXmlString(pretty: true, indent: '  ');
  }
}