import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';
import 'package:path/path.dart' as p;
import 'package:gen_l10n_utils/src/cli/commands/gen_arb_command.dart';

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
  late MockFile mockNestedFile;

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

    mockNestedFile = MockFile();

    mockArbFileList = [
      mockArbFiles['en']!,
      mockArbFiles['de']!,
      mockNestedFile,
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

    when(mockArbFiles['en']!.path).thenReturn(
        p.join(basePath, 'features', 'home', 'l10n', 'en', 'texts.arb'));
    when(mockArbFiles['de']!.path).thenReturn(
        p.join(basePath, 'features', 'home', 'l10n', 'de', 'texts.arb'));
    when(mockNestedFile.path).thenReturn(
        p.join(basePath, 'features', 'settings', 'l10n', 'en', 'texts.arb'));

    when(mockArbFiles['en']!.existsSync()).thenReturn(true);
    when(mockArbFiles['de']!.existsSync()).thenReturn(true);
    when(mockNestedFile.existsSync()).thenReturn(true);

    when(mockArbFiles['en']!.readAsStringSync()).thenReturn(jsonEncode({
      'settings.title': 'Settings',
      'characters.title': 'Characters',
    }));

    when(mockArbFiles['de']!.readAsStringSync()).thenReturn(jsonEncode({
      'settings.title': 'Einstellungen',
      'characters.title': 'Charaktere',
    }));

    when(mockNestedFile.readAsStringSync()).thenReturn(jsonEncode({
      'settings': {'volume': 'Volume', 'rotation': 'Rotation'}
    }));
  });

  group('Configuration handling', () {
    test('Throws an error if config file is missing', () {
      when(mockConfigFile.existsSync()).thenReturn(false);
      expect(
        suppressPrints(() =>
            command.genArb(mockTempDir.path, mockConfigFile, mockArbFileList)),
        throwsA(isA<Exception>()),
      );
    });

    test('Throws an error if config file is invalid', () {
      when(mockConfigFile.readAsStringSync())
          .thenReturn('invalid yaml content');
      expect(
        suppressPrints(() =>
            command.genArb(mockTempDir.path, mockConfigFile, mockArbFileList)),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('ARB file processing', () {
    test('Correctly identifies language files by directory path', () {
      final mockExtraFile = MockFile();
      when(mockExtraFile.path)
          .thenReturn(p.join('/mock/temp', 'widgets', 'texts.arb'));
      when(mockExtraFile.existsSync()).thenReturn(true);
      when(mockExtraFile.readAsStringSync()).thenReturn('{}');

      final allFiles = [...mockArbFileList, mockExtraFile];

      suppressPrints(
              () => command.genArb(mockTempDir.path, mockConfigFile, allFiles))();

      verify(mockArbFiles['en']!.readAsStringSync()).called(1);
      verify(mockArbFiles['de']!.readAsStringSync()).called(1);
      verify(mockNestedFile.readAsStringSync()).called(1);
      verifyNever(mockExtraFile.readAsStringSync());
    });

    test('Merges and flattens ARB files correctly', () {
      // Set up output file mock
      final mockOutputFile = MockFile();
      Map<String, dynamic> capturedEnContent = {};
      Map<String, dynamic> capturedDeContent = {};

      when(mockOutputFile.path).thenReturn('');

      when(mockOutputFile.writeAsStringSync(any)).thenAnswer((invocation) {
        final content = invocation.positionalArguments.first as String;
        final json = jsonDecode(content) as Map<String, dynamic>;

        // Store the content based on what appears to be in it
        if (json.containsKey('settings.title') &&
            json['settings.title'] == 'Settings') {
          capturedEnContent = json;
        } else if (json.containsKey('settings.title') &&
            json['settings.title'] == 'Einstellungen') {
          capturedDeContent = json;
        }
      });

      // Run the test
      suppressPrints(() => command.genArb(
          mockTempDir.path, mockConfigFile, mockArbFileList,
          mockOutputFile: mockOutputFile))();

      // Verify the content
      expect(capturedEnContent.isNotEmpty, isTrue);
      expect(capturedDeContent.isNotEmpty, isTrue);

      expect(capturedEnContent, containsPair('settings.title', 'Settings'));
      expect(capturedEnContent, containsPair('characters.title', 'Characters'));
      expect(capturedEnContent, containsPair('settings.volume', 'Volume'));
      expect(capturedEnContent, containsPair('settings.rotation', 'Rotation'));

      expect(
          capturedDeContent, containsPair('settings.title', 'Einstellungen'));
      expect(capturedDeContent, containsPair('characters.title', 'Charaktere'));
    });

    test('Alphabetically sorts keys in output ARB files', () {
      // Set up mock ARB files with keys in non-alphabetical order
      when(mockArbFiles['en']!.readAsStringSync()).thenReturn(jsonEncode({
        'zebra': 'Zebra',
        'apple': 'Apple',
        'banana': 'Banana'
      }));

      // Set up output file mock
      final mockOutputFile = MockFile();
      String? capturedContent;

      when(mockOutputFile.path).thenReturn('');
      when(mockOutputFile.writeAsStringSync(any)).thenAnswer((invocation) {
        capturedContent = invocation.positionalArguments.first as String;
      });

      // Run the test
      suppressPrints(() => command.genArb(
          mockTempDir.path, mockConfigFile, [mockArbFiles['en']!],
          mockOutputFile: mockOutputFile))();

      // Verify the content is sorted
      expect(capturedContent, isNotNull);
      final json = jsonDecode(capturedContent!) as Map<String, dynamic>;

      // Extract keys and check if they're sorted
      final keys = json.keys.toList();
      expect(keys, equals(['apple', 'banana', 'zebra']),
          reason: 'Keys should be sorted alphabetically');
    });

    test('Flattens nested JSON structures', () {
      final flattened = command.flattenJson({
        'settings': {
          'volume': 'Volume',
          'brightness': {
            'auto': 'Auto brightness',
            'manual': 'Manual brightness'
          }
        },
        'simple': 'Simple value'
      });

      expect(
          flattened,
          equals({
            'settings.volume': 'Volume',
            'settings.brightness.auto': 'Auto brightness',
            'settings.brightness.manual': 'Manual brightness',
            'simple': 'Simple value'
          }));
    });

    test('Handles missing translations gracefully', () {
      when(mockArbFiles['en']!.readAsStringSync()).thenReturn(jsonEncode({
        'settings.title': 'Settings',
      }));
      when(mockArbFiles['de']!.readAsStringSync()).thenReturn(jsonEncode({
        'settings.title': 'Einstellungen',
      }));

      suppressPrints(() =>
          command.genArb(mockTempDir.path, mockConfigFile, mockArbFileList))();

      verify(mockArbFiles['en']!.readAsStringSync()).called(1);
      verify(mockArbFiles['de']!.readAsStringSync()).called(1);
      verify(mockNestedFile.readAsStringSync()).called(1);
    });

    test('Throws an error if no translations are found', () {
      expect(
        suppressPrints(
                () => command.genArb(mockTempDir.path, mockConfigFile, [])),
        throwsA(isA<Exception>()),
      );
    });

    test('Detects and correctly handles key conflicts', () {
      // Set up conflicting ARB files
      final mockConflictFile = MockFile();
      when(mockConflictFile.path).thenReturn(
          p.join('/mock/temp', 'features', 'settings', 'l10n', 'en', 'conflicts.arb'));
      when(mockConflictFile.existsSync()).thenReturn(true);
      when(mockConflictFile.readAsStringSync()).thenReturn(jsonEncode({
        'settings.title': 'App Settings', // This conflicts with existing "Settings" value
      }));

      final testFiles = [...mockArbFileList, mockConflictFile];

      // Set up to capture content
      final mockOutputFile = MockFile();
      Map<String, dynamic>? capturedEnContent;

      when(mockOutputFile.path).thenReturn('');

      // The key issue is here - we need to be able to distinguish between languages in the output
      int writeCount = 0;
      when(mockOutputFile.writeAsStringSync(any)).thenAnswer((invocation) {
        final content = invocation.positionalArguments.first as String;
        final json = jsonDecode(content) as Map<String, dynamic>;

        // For English file only (first write in our test)
        if (writeCount == 0) {
          capturedEnContent = json;
        }
        writeCount++;
      });

      // Execute with conflict detection
      suppressPrints(() => command.genArb(
          mockTempDir.path, mockConfigFile, testFiles,
          mockOutputFile: mockOutputFile))();

      // First occurrence wins - should have "Settings" not "App Settings"
      expect(capturedEnContent, isNotNull);
      expect(capturedEnContent!['settings.title'], equals('Settings'));

      // Test the internal mergeArbFilesWithConflictDetection function directly
      final result = command.mergeArbFilesWithConflictDetection([
        mockArbFiles['en']!,
        mockConflictFile
      ]);

      // Verify conflicts were detected
      expect(result.conflicts.isNotEmpty, isTrue);
      expect(result.conflicts.containsKey('settings.title'), isTrue);
      expect(result.conflicts['settings.title']![0].value, equals('App Settings'));
      expect(result.conflicts['settings.title']![0].existingValue, equals('Settings'));
    });
  });

  group('Output generation', () {
    test('Writes merged translations to output files', () {
      // Use a single mock but track writes with a counter
      final mockOutputFile = MockFile();
      int writeCount = 0;

      when(mockOutputFile.path).thenReturn('');
      when(mockOutputFile.writeAsStringSync(any)).thenAnswer((_) {
        writeCount++;
      });

      // Run the command
      suppressPrints(() => command.genArb(
          mockTempDir.path, mockConfigFile, mockArbFileList,
          mockOutputFile: mockOutputFile))();

      // Verify we wrote exactly twice (once for each language)
      expect(writeCount, equals(2));
    });
  });
}