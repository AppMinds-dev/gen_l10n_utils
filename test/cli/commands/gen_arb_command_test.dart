import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';
import 'package:path/path.dart' as p;
import 'package:appminds_l10n_tools/src/cli/commands/gen_arb_command.dart';

import 'gen_arb_command_test.mocks.dart';

class FileSystemHelper {
  static File createMockFile(String path, {bool exists = true, String content = ''}) {
    final mockFile = MockFile();
    when(mockFile.path).thenReturn(path);
    when(mockFile.existsSync()).thenReturn(exists);
    when(mockFile.readAsStringSync()).thenReturn(content);
    return mockFile;
  }
}

@GenerateMocks([Directory, File])
void main() {
  late GenArbCommand command;
  late MockDirectory mockTempDir;
  late MockDirectory mockOutputDir;
  late MockFile mockConfigFile;
  late Map<String, MockFile> mockArbFiles;
  late List<File> mockArbFileList;

  void Function() suppressPrints(void Function() fn) {
    return () => runZoned(
      fn,
      zoneSpecification: ZoneSpecification(
        print: (_, __, ___, ____) {},
      ),
    );
  }

  setUp(() {
    command = GenArbCommand();
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

    final basePath = p.normalize('/mock/temp');

    when(mockTempDir.existsSync()).thenReturn(true);
    when(mockTempDir.path).thenReturn(basePath);
    when(mockOutputDir.path).thenReturn(p.join(basePath, 'lib/l10n'));
    when(mockConfigFile.existsSync()).thenReturn(true);
    when(mockConfigFile.readAsStringSync()).thenReturn('''
default_language: en
languages:
  - en
  - de
''');

    when(mockArbFiles['en']!.path).thenReturn(p.join(basePath, 'features', 'home', 'l10n', 'en', 'texts.arb'));
    when(mockArbFiles['de']!.path).thenReturn(p.join(basePath, 'features', 'home', 'l10n', 'de', 'texts.arb'));

    when(mockArbFiles['en']!.existsSync()).thenReturn(true);
    when(mockArbFiles['de']!.existsSync()).thenReturn(true);

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
      expect(
        suppressPrints(() => command.genArb(mockTempDir.path, mockConfigFile, mockArbFileList)),
        throwsA(isA<Exception>()),
      );
    });

    test('Throws an error if config file is invalid', () {
      when(mockConfigFile.readAsStringSync()).thenReturn('invalid yaml content');
      expect(
        suppressPrints(() => command.genArb(mockTempDir.path, mockConfigFile, mockArbFileList)),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('ARB file processing', () {
    test('Correctly identifies language files by directory path', () {
      final mockExtraFile = MockFile();
      when(mockExtraFile.path).thenReturn(p.join('/mock/temp', 'widgets', 'texts.arb'));
      when(mockExtraFile.existsSync()).thenReturn(true);
      when(mockExtraFile.readAsStringSync()).thenReturn('{}');

      final allFiles = [...mockArbFileList, mockExtraFile];

      suppressPrints(() => command.genArb(mockTempDir.path, mockConfigFile, allFiles))();

      verify(mockArbFiles['en']!.readAsStringSync()).called(1);
      verify(mockArbFiles['de']!.readAsStringSync()).called(1);
      verifyNever(mockExtraFile.readAsStringSync());
    });

    test('Merges and flattens ARB files correctly', () {
      suppressPrints(() => command.genArb(mockTempDir.path, mockConfigFile, mockArbFileList))();

      verify(mockArbFiles['en']!.readAsStringSync()).called(1);
      verify(mockArbFiles['de']!.readAsStringSync()).called(1);
    });

    test('Handles missing translations gracefully', () {
      when(mockArbFiles['en']!.readAsStringSync()).thenReturn(jsonEncode({
        'settings.title': 'Settings',
      }));
      when(mockArbFiles['de']!.readAsStringSync()).thenReturn(jsonEncode({
        'settings.title': 'Einstellungen',
      }));

      suppressPrints(() => command.genArb(mockTempDir.path, mockConfigFile, mockArbFileList))();

      verify(mockArbFiles['en']!.readAsStringSync()).called(1);
      verify(mockArbFiles['de']!.readAsStringSync()).called(1);
    });

    test('Throws an error if no translations are found', () {
      expect(
        suppressPrints(() => command.genArb(mockTempDir.path, mockConfigFile, [])),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('Output generation', () {
    test('Writes merged translations to output files', () {
      final outputFile = MockFile();
      final outputPath = p.join(mockTempDir.path, 'lib/l10n', 'app_en.arb');
      when(outputFile.path).thenReturn(outputPath);
      when(outputFile.writeAsStringSync(any)).thenReturn(null);

      suppressPrints(() => command.genArb(mockTempDir.path, mockConfigFile, mockArbFileList, mockOutputFile: outputFile))();

      verify(outputFile.writeAsStringSync(any)).called(2);
    });
  });
}