import 'package:gen_l10n_utils/src/utils/export/format_converter.dart';
import 'package:gen_l10n_utils/src/utils/export/xliff_converter.dart';
import 'package:gen_l10n_utils/src/utils/export/json_converter.dart';
import 'package:gen_l10n_utils/src/utils/export/po_converter.dart';
import 'package:gen_l10n_utils/src/utils/export/yaml_converter.dart';
import 'package:gen_l10n_utils/src/utils/export/xlsx_converter.dart';

class ArbConverter {
  final Map<String, FormatConverter> _converters = {
    'xlf': XliffConverter(),
    'json': JsonConverter(),
    'po': PoConverter(),
    'yaml': YamlConverter(),
    'xlsx': XlsxConverter(),
  };

  /// Converts ARB files to the specified format
  void convert({
    required String format,
    required String baseLanguage,
    required List<String> languages,
    required String inputDir,
    required String outputDir,
  }) {
    final converter = _converters[format];
    if (converter == null) {
      throw FormatException(
        'Unsupported format: $format. Supported formats: ${supportedFormats.join(", ")}',
      );
    }

    converter.convert(
      baseLanguage: baseLanguage,
      languages: languages,
      inputDir: inputDir,
      outputDir: outputDir,
    );
  }

  /// Returns a list of supported export formats
  List<String> get supportedFormats => _converters.keys.toList();
}
