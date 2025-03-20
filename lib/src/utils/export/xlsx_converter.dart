import 'dart:convert';
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path/path.dart' as path;
import 'package:gen_l10n_utils/src/utils/export/format_converter.dart';

class XlsxConverter implements FormatConverter {
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

      final excel = convertToXlsx(
        sourceLanguage: baseLanguage,
        targetLanguage: language,
        sourceContent: baseContent,
        targetContent: targetContent,
      );

      final outputPath = path.join(outputDir, 'xlsx', 'app_$language.xlsx');
      _ensureDirectoryExists(outputPath);
      saveToFile(excel, outputPath);
    }
  }

  /// Converts ARB content to Excel format
  Excel convertToXlsx({
    required String sourceLanguage,
    required String targetLanguage,
    required Map<String, dynamic> sourceContent,
    required Map<String, dynamic> targetContent,
  }) {
    final excel = Excel.createExcel();

    // Create overview sheet
    final overview = excel['Overview'];
    _writeOverviewSheet(
      sheet: overview,
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
    );

    // Create translations sheet
    final translations = excel['Translations'];
    _writeTranslationsSheet(
      sheet: translations,
      sourceContent: sourceContent,
      targetContent: targetContent,
    );

    // Create metadata sheet
    final metadata = excel['Metadata'];
    _writeMetadataSheet(
      sheet: metadata,
      sourceContent: sourceContent,
    );

    // Remove default sheet
    // if (excel.sheets.containsKey('Sheet1')) {
    //   excel.delete('Sheet1');
    // }

    return excel;
  }

  void _writeOverviewSheet({
    required Sheet sheet,
    required String sourceLanguage,
    required String targetLanguage,
  }) {
    // Set column widths
    sheet.setColumnWidth(0, 20);
    sheet.setColumnWidth(1, 40);

    // Write header
    final headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: '#E0E0E0',
    );

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
      ..value = 'Property'
      ..cellStyle = headerStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0))
      ..value = 'Value'
      ..cellStyle = headerStyle;

    // Write metadata
    var row = 1;
    _writeOverviewRow(sheet, row++, 'Tool', 'gen_l10n_utils');
    _writeOverviewRow(sheet, row++, 'Format Version', '1.0');
    _writeOverviewRow(sheet, row++, 'Source Language', sourceLanguage);
    _writeOverviewRow(sheet, row++, 'Target Language', targetLanguage);
    _writeOverviewRow(
      sheet,
      row++,
      'Export Date',
      DateTime.now().toIso8601String(),
    );
  }

  void _writeOverviewRow(Sheet sheet, int row, String key, String value) {
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        .value = key;
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
        .value = value;
  }

  void _writeTranslationsSheet({
    required Sheet sheet,
    required Map<String, dynamic> sourceContent,
    required Map<String, dynamic> targetContent,
  }) {
    // Set column widths
    sheet.setColumnWidth(0, 30);
    sheet.setColumnWidth(1, 50);
    sheet.setColumnWidth(2, 50);

    // Write header
    final headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: '#E0E0E0',
    );

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
      ..value = 'Key'
      ..cellStyle = headerStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0))
      ..value = 'Source'
      ..cellStyle = headerStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 0))
      ..value = 'Target'
      ..cellStyle = headerStyle;

    // Write translations
    var row = 1;
    for (final key in sourceContent.keys) {
      if (!key.startsWith('@')) {
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
            .value = key;
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
            .value = sourceContent[key] as String;
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
            .value = targetContent[key] as String? ?? '';
        row++;
      }
    }
  }

  void _writeMetadataSheet({
    required Sheet sheet,
    required Map<String, dynamic> sourceContent,
  }) {
    // Set column widths
    sheet.setColumnWidth(0, 30);
    sheet.setColumnWidth(1, 40);
    sheet.setColumnWidth(2, 40);
    sheet.setColumnWidth(3, 40);

    // Write header
    final headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: '#E0E0E0',
    );

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
      ..value = 'Key'
      ..cellStyle = headerStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0))
      ..value = 'Description'
      ..cellStyle = headerStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 0))
      ..value = 'Placeholder'
      ..cellStyle = headerStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 0))
      ..value = 'Placeholder Details'
      ..cellStyle = headerStyle;

    // Write metadata
    var row = 1;
    for (final key in sourceContent.keys) {
      if (!key.startsWith('@')) {
        final metadata = sourceContent['@$key'] as Map<String, dynamic>?;
        if (metadata != null) {
          final description = metadata['description'] as String?;
          final placeholders =
              metadata['placeholders'] as Map<String, dynamic>?;

          if (placeholders != null) {
            for (final placeholder in placeholders.entries) {
              final details = [
                if (placeholder.value['type'] != null)
                  'Type: ${placeholder.value['type']}',
                if (placeholder.value['example'] != null)
                  'Example: ${placeholder.value['example']}',
                if (placeholder.value['description'] != null)
                  'Description: ${placeholder.value['description']}',
              ].join('\n');

              sheet
                  .cell(
                      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
                  .value = key;
              sheet
                  .cell(
                      CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
                  .value = description ?? '';
              sheet
                  .cell(
                      CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
                  .value = placeholder.key;
              sheet
                  .cell(
                      CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row))
                  .value = details;

              row++;
            }
          } else {
            sheet
                .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
                .value = key;
            sheet
                .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
                .value = description ?? '';
            row++;
          }
        }
      }
    }
  }

  /// Saves Excel content to a file
  void saveToFile(Excel excel, String outputPath) {
    final file = File(outputPath);
    file.writeAsBytesSync(excel.encode()!);
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
