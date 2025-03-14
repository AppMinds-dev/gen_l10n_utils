import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';
import 'package:path/path.dart' as p;
import 'package:appminds_l10n_tools/appminds_l10n_tools.dart';

import 'generate_translations_test.mocks.dart';

@GenerateMocks([Directory, File])
void main() {
  late MockDirectory mockTempDir;
  late MockDirectory mockOutputDir;
  late MockFile mockConfigFile;
  late Map<String, MockFile> mockArbFiles;
  late List<File> mockArbFileList;

  setUp(() {
    mockTempDir = MockDirectory();
    mockOutputDir = MockDirectory();
    mockConfigFile = MockFile();

    mockArbFiles = {
      'en': MockFile(),
      'de': MockFile(),
    };

    mockArbFileList = [
      mockArbFiles['en']!,
      mockArbFiles['de']!,
    ];

    // Use consistent path separators for all paths
    final basePath = p.normalize('/mock/temp');

    when(mockTempDir.existsSync()).thenReturn(true);
    when(mockTempDir.path).thenReturn(basePath);
    when(mockOutputDir.path).thenReturn(p.join(basePath, 'l10n'));
    when(mockConfigFile.existsSync()).thenReturn(true);
    when(mockConfigFile.readAsStringSync()).thenReturn('''
default_language: en
languages:
  - en
  - de
''');

    // Add stubs for the path method - must include language code in filename
    when(mockArbFiles['en']!.path).thenReturn(p.join(basePath, 'en_en.arb'));
    when(mockArbFiles['de']!.path).thenReturn(p.join(basePath, 'de_de.arb'));

    // Add existsSync stubs
    when(mockArbFiles['en']!.existsSync()).thenReturn(true);
    when(mockArbFiles['de']!.existsSync()).thenReturn(true);

    // Add readAsStringSync stubs
    when(mockArbFiles['en']!.readAsStringSync()).thenReturn(jsonEncode({
      'settings.title': 'Settings',
      'characters.title': 'Characters',
    }));

    when(mockArbFiles['de']!.readAsStringSync()).thenReturn(jsonEncode({
      'settings.title': 'Einstellungen',
      'characters.title': 'Charaktere',
    }));
  });

  group('Configuration handling', () {
    test('Throws an error if config file is missing', () {
      when(mockConfigFile.existsSync()).thenReturn(false);
      expect(() => generateTranslations(mockTempDir.path, mockConfigFile, mockArbFileList),
          throwsA(isA<Exception>()));
    });

    test('Throws an error if config file is invalid', () {
      when(mockConfigFile.readAsStringSync()).thenReturn('invalid yaml content');
      expect(() => generateTranslations(mockTempDir.path, mockConfigFile, mockArbFileList),
          throwsA(isA<Exception>()));
    });
  });

  group('ARB file processing', () {
    test('Merges and flattens ARB files correctly', () {
      // Run test in a zone that captures prints
      runZoned(() {
        generateTranslations(mockTempDir.path, mockConfigFile, mockArbFileList);
      }, zoneSpecification: ZoneSpecification(
          print: (_, __, ___, String message) {
            // Ignore print statements
          }
      ));

      verify(mockArbFiles['en']!.readAsStringSync()).called(1);
      verify(mockArbFiles['de']!.readAsStringSync()).called(1);
    });

    test('Handles missing translations gracefully', () {
      // Update the content to simulate missing translations
      when(mockArbFiles['en']!.readAsStringSync()).thenReturn(jsonEncode({
        'settings.title': 'Settings',
      }));

      when(mockArbFiles['de']!.readAsStringSync()).thenReturn(jsonEncode({
        'settings.title': 'Einstellungen',
      }));

      runZoned(() {
        generateTranslations(mockTempDir.path, mockConfigFile, mockArbFileList);
      }, zoneSpecification: ZoneSpecification(
          print: (_, __, ___, String message) {
            // Ignore print statements
          }
      ));

      verify(mockArbFiles['en']!.readAsStringSync()).called(1);
      verify(mockArbFiles['de']!.readAsStringSync()).called(1);
    });

    test('Throws an error if no translations are found', () {
      expect(() => generateTranslations(mockTempDir.path, mockConfigFile, []),
          throwsA(isA<Exception>()));
    });

    test('Fails if no language files exist', () {
      final emptyList = <File>[];
      expect(() => generateTranslations(mockTempDir.path, mockConfigFile, emptyList),
          throwsA(isA<Exception>()));
    });
  });

  group('Output generation', () {
    test('Writes merged translations to output files', () {
      final outputFile = MockFile();
      final outputPath = p.join(mockTempDir.path, 'l10n', 'app_en.arb');
      when(outputFile.path).thenReturn(outputPath);
      when(outputFile.writeAsStringSync(any)).thenReturn(null);

      runZoned(() {
        generateTranslations(mockTempDir.path, mockConfigFile, mockArbFileList, mockOutputFile: outputFile);
      }, zoneSpecification: ZoneSpecification(
          print: (_, __, ___, String message) {
            // Ignore print statements
          }
      ));

      // When mockOutputFile is provided, it's used for all languages
      verify(outputFile.writeAsStringSync(any)).called(2);
    });
  });
}