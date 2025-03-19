import 'dart:io';
import 'package:xml/xml.dart';

class XliffConverter {
  /// Converts ARB content to XLIFF format
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
      for (final key in sourceContent.keys) {
        if (!key.startsWith('@')) {
          final metadata = sourceContent['@$key'] as Map<String, dynamic>?;
          _buildTransUnit(
            builder,
            id: key,
            source: sourceContent[key] as String,
            target: targetContent[key] as String?,
            metadata: metadata,
          );
        }
      }
    });
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
      if (target != null) {
        builder.element('target', nest: target);
      }

      if (metadata != null) {
        final description = metadata['description'] as String?;
        if (description != null && description.isNotEmpty) {
          builder.element('note', attributes: {'priority': '1'}, nest: description);
        }

        final placeholders = metadata['placeholders'] as Map<String, dynamic>?;
        if (placeholders != null) {
          for (final placeholder in placeholders.entries) {
            final name = placeholder.key;
            final props = placeholder.value as Map<String, dynamic>;
            final note = [
              if (props['type'] != null) 'Type: ${props['type']}',
              if (props['example'] != null) 'Example: ${props['example']}',
              if (props['description'] != null)
                'Description: ${props['description']}',
            ].join(', ');

            if (note.isNotEmpty) {
              builder.element('note', attributes: {
                'from': 'placeholder',
                'name': name,
              }, nest: note);
            }
          }
        }
      }
    });
  }

  /// Saves XLIFF content to a file
  void saveToFile(XmlDocument xliff, String outputPath) {
    final file = File(outputPath);
    file.writeAsStringSync(xliff.toXmlString(pretty: true));
  }
}