import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:gen_l10n_utils/src/utils/export/xliff_converter.dart';
import 'package:gen_l10n_utils/src/utils/export/json_converter.dart';

class ArbConverter {
  final xliffConverter = XliffConverter();
  final jsonConverter = JsonConverter();

  void convertToXlf({
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

      final xliff = xliffConverter.convertToXliff(
        sourceLanguage: baseLanguage,
        targetLanguage: language,
        sourceContent: baseContent,
        targetContent: targetContent,
      );

      final outputPath = path.join(outputDir, 'xlf', 'app_$language.xlf');
      _ensureDirectoryExists(outputPath);
      xliffConverter.saveToFile(xliff, outputPath);
    }
  }

  void convertToJson({
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

      final json = jsonConverter.convertToJson(
        sourceContent: baseContent,
        targetContent: targetContent,
      );

      final outputPath = path.join(outputDir, 'json', 'app_$language.json');
      _ensureDirectoryExists(outputPath);
      jsonConverter.saveToFile(json, outputPath);
    }
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
