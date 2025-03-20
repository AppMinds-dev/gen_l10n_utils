import 'dart:convert';
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path/path.dart' as path;
import 'package:gen_l10n_utils/src/utils/export/format_converter.dart';

class XlsxConverter implements FormatConverter {
  final _headerStyle = CellStyle(
    backgroundColorHex: ExcelColor.grey300,
    bold: true,
  );

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

  Excel convertToXlsx({
    required String sourceLanguage,
    required String targetLanguage,
    required Map<String, dynamic> sourceContent,
    required Map<String, dynamic> targetContent,
  }) {
    final excel = Excel.createExcel();

    final overview = excel['Overview'];
    _writeOverviewSheet(
      sheet: overview,
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
    );

    final translations = excel['Translations'];
    _writeTranslationsSheet(
      sheet: translations,
      sourceContent: sourceContent,
      targetContent: targetContent,
    );

    final metadata = excel['Metadata'];
    _writeMetadataSheet(
      sheet: metadata,
      sourceContent: sourceContent,
    );

    // Remove default sheet
    excel.delete('Sheet1');

    return excel;
  }

  void _writeOverviewSheet({
    required Sheet sheet,
    required String sourceLanguage,
    required String targetLanguage,
  }) {
    sheet.setColumnWidth(0, 20);
    sheet.setColumnWidth(1, 40);

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
      ..value = TextCellValue('Property')
      ..cellStyle = _headerStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0))
      ..value = TextCellValue('Value')
      ..cellStyle = _headerStyle;

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
        .value = TextCellValue(key);
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
        .value = TextCellValue(value);
  }

  void _writeTranslationsSheet({
    required Sheet sheet,
    required Map<String, dynamic> sourceContent,
    required Map<String, dynamic> targetContent,
  }) {
    sheet.setColumnWidth(0, 30);
    sheet.setColumnWidth(1, 50);
    sheet.setColumnWidth(2, 50);

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
      ..value = TextCellValue('Key')
      ..cellStyle = _headerStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0))
      ..value = TextCellValue('Source')
      ..cellStyle = _headerStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 0))
      ..value = TextCellValue('Target')
      ..cellStyle = _headerStyle;

    var row = 1;
    _processTranslations(
      sheet: sheet,
      sourceContent: sourceContent,
      targetContent: targetContent,
      rowIndex: row,
    );
  }

  int _processTranslations({
    required Sheet sheet,
    required Map<String, dynamic> sourceContent,
    required Map<String, dynamic> targetContent,
    required int rowIndex,
    String prefix = '',
  }) {
    var row = rowIndex;
    for (final key in sourceContent.keys) {
      if (!key.startsWith('@')) {
        final value = sourceContent[key];
        if (value is Map<String, dynamic>) {
          // Handle nested structures
          row = _processTranslations(
            sheet: sheet,
            sourceContent: value,
            targetContent: targetContent[key] ?? {},
            rowIndex: row,
            prefix: prefix.isEmpty ? key : '$prefix.$key',
          );
        } else {
          final fullKey = prefix.isEmpty ? key : '$prefix.$key';
          final targetMap = prefix.isEmpty
              ? targetContent
              : _getNestedValue(targetContent, prefix.split('.'));

          sheet
              .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
              .value = TextCellValue(fullKey);
          sheet
              .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
              .value = TextCellValue(value as String);
          sheet
              .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
              .value = TextCellValue(targetMap?[key] as String? ?? '');

          row++;
        }
      }
    }
    return row;
  }

  void _writeMetadataSheet({
    required Sheet sheet,
    required Map<String, dynamic> sourceContent,
  }) {
    sheet.setColumnWidth(0, 30);
    sheet.setColumnWidth(1, 40);
    sheet.setColumnWidth(2, 40);
    sheet.setColumnWidth(3, 40);

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
      ..value = TextCellValue('Key')
      ..cellStyle = _headerStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0))
      ..value = TextCellValue('Description')
      ..cellStyle = _headerStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 0))
      ..value = TextCellValue('Placeholder')
      ..cellStyle = _headerStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 0))
      ..value = TextCellValue('Placeholder Details')
      ..cellStyle = _headerStyle;

    var row = 1;
    _processMetadata(
      sheet: sheet,
      sourceContent: sourceContent,
      rowIndex: row,
    );
  }

  int _processMetadata({
    required Sheet sheet,
    required Map<String, dynamic> sourceContent,
    required int rowIndex,
    String prefix = '',
  }) {
    var row = rowIndex;
    for (final key in sourceContent.keys) {
      if (!key.startsWith('@')) {
        final value = sourceContent[key];
        if (value is Map<String, dynamic>) {
          row = _processMetadata(
            sheet: sheet,
            sourceContent: value,
            rowIndex: row,
            prefix: prefix.isEmpty ? key : '$prefix.$key',
          );
        } else {
          final fullKey = prefix.isEmpty ? key : '$prefix.$key';
          final metadataKey = '@$key';
          final metadata = sourceContent[metadataKey] as Map<String, dynamic>?;

          if (metadata != null) {
            final description = metadata['description'] as String?;
            final placeholders =
                metadata['placeholders'] as Map<String, dynamic>?;

            if (placeholders != null) {
              for (final placeholder in placeholders.entries) {
                final details = [
                  if (placeholder.value['type'] != null)
                    'type: ${placeholder.value['type']}',
                  if (placeholder.value['example'] != null)
                    'example: ${placeholder.value['example']}',
                  if (placeholder.value['description'] != null)
                    'desc: ${placeholder.value['description']}',
                ].join(', ');

                sheet
                    .cell(CellIndex.indexByColumnRow(
                        columnIndex: 0, rowIndex: row))
                    .value = TextCellValue(fullKey);
                sheet
                    .cell(CellIndex.indexByColumnRow(
                        columnIndex: 1, rowIndex: row))
                    .value = TextCellValue(description ?? '');
                sheet
                    .cell(CellIndex.indexByColumnRow(
                        columnIndex: 2, rowIndex: row))
                    .value = TextCellValue(placeholder.key);
                sheet
                    .cell(CellIndex.indexByColumnRow(
                        columnIndex: 3, rowIndex: row))
                    .value = TextCellValue(details);

                row++;
              }
            } else if (description != null && description.isNotEmpty) {
              sheet
                  .cell(
                      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
                  .value = TextCellValue(fullKey);
              sheet
                  .cell(
                      CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
                  .value = TextCellValue(description);

              row++;
            }
          }
        }
      }
    }
    return row;
  }

  dynamic _getNestedValue(Map<String, dynamic> map, List<String> keys) {
    var current = map;
    for (var i = 0; i < keys.length; i++) {
      current = current[keys[i]] as Map<String, dynamic>? ?? {};
    }
    return current;
  }

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
