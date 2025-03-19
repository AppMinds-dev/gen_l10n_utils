import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:args/args.dart';
import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:path/path.dart' as p;
import 'package:gen_l10n_utils/src/cli/commands/gen_arb_command.dart';

import '../../utils/command_test_base.dart';
import '../../utils/command_test_base_annotations.mocks.dart';

class TestableGenArbCommand extends GenArbCommand {
  ArgResults? testArgResults;

  @override
  ArgResults get argResults => testArgResults ?? super.argResults!;
}

class TestGenArbCommand extends TestCommandBase<GenArbCommand> {
  @override
  ArgParser get argParser => GenArbCommand().argParser;

  late TestableGenArbCommand command;
  List<File>? testArbFiles;

  GenArbCommand createCommand() {
    command = TestableGenArbCommand();
    command.testArgResults = testArgResults;
    return command;
  }

  Future<int> runGenArb(String basePath, [MockFile? mockOutputFile]) async {
    try {
      command.genArb(basePath, testFile!, testArbFiles ?? [],
          mockOutputFile: mockOutputFile);
      return Future.value(0);
    } catch (e) {
      rethrow;
    }
  }
}

void main() {
  late CommandTestBase testBase;
  late TestGenArbCommand testHelper;
  late Map<String, MockFile> mockArbFiles;
  late List<File> mockArbFileList;
  late MockFile mockNestedFile;

  setUp(() {
    testBase = CommandTestBase();
    testBase.setUp();

    when(testBase.mockConfigFile.existsSync()).thenReturn(true);
    when(testBase.mockConfigFile.path).thenReturn('gen_l10n_utils.yaml');

    testHelper = TestGenArbCommand();
    testHelper.testFile = testBase.mockConfigFile;
    testHelper.testLibDir = testBase.mockLibDir;

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

    testHelper.testArbFiles = mockArbFileList;

    final basePath = p.normalize('/mock/temp');

    when(testBase.mockLibDir.path).thenReturn(basePath);
    when(testBase.mockConfigFile.readAsStringSync()).thenReturn('''
base_language: en
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

    when(testBase.mockConfigFile.writeAsString(any))
        .thenAnswer((_) => Future.value(testBase.mockConfigFile));
  });

  group('Command configuration', () {
    test('Has correct name and description', () {
      final command = GenArbCommand();
      expect(command.name, equals('gen-arb'));
      expect(command.description, isNotEmpty);
    });

    test('Uses correct config file name', () {
      expect(GenArbCommand.configFileName, equals('gen_l10n_utils.yaml'));
    });
  });

  group('Configuration handling', () {
    test('Handles invalid YAML content', () async {
      when(testBase.mockConfigFile.readAsStringSync())
          .thenReturn('invalid: [yaml: content');

      testHelper.configureWithArgs([]);
      final command = testHelper.createCommand();

      final result = await command.run();
      expect(result, equals(1));
    });

    test('Handles invalid config structure', () {
      when(testBase.mockConfigFile.readAsStringSync())
          .thenReturn('some: value');

      testHelper.configureWithArgs([]);
      testHelper.createCommand();

      expect(
        () => testHelper.runGenArb(testBase.mockLibDir.path),
        throwsA(predicate((e) =>
            e is Exception &&
            e.toString().contains('Invalid configuration format'))),
      );
    });
  });

  group('ARB file processing', () {
    // test('Correctly identifies language files by directory path', () {
    //   final mockExtraFile = MockFile();
    //   when(mockExtraFile.path)
    //       .thenReturn(p.join('/mock/temp', 'widgets', 'texts.arb'));
    //   when(mockExtraFile.existsSync()).thenReturn(true);
    //   when(mockExtraFile.readAsStringSync()).thenReturn('{}');
    //
    //   testHelper.testArbFiles = [...mockArbFileList, mockExtraFile];
    //
    //   testHelper.configureWithArgs([]);
    //   testHelper.createCommand();
    //
    //   testHelper.runGenArb(testBase.mockLibDir.path);
    //
    //   verify(mockArbFiles['en']!.readAsStringSync()).called(1);
    //   verify(mockArbFiles['de']!.readAsStringSync()).called(1);
    //   verify(mockNestedFile.readAsStringSync()).called(1);
    //   verifyNever(mockExtraFile.readAsStringSync());
    // });

    // test('Merges and flattens ARB files correctly', () {
    //   final mockOutputFile = MockFile();
    //   Map<String, dynamic> capturedEnContent = {};
    //   Map<String, dynamic> capturedDeContent = {};
    //
    //   when(mockOutputFile.path)
    //       .thenReturn(p.join('/mock/temp', 'lib/l10n/app_en.arb'));
    //   when(mockOutputFile.writeAsStringSync(any)).thenAnswer((invocation) {
    //     final content = invocation.positionalArguments.first as String;
    //     final json = jsonDecode(content) as Map<String, dynamic>;
    //
    //     if (json.containsKey('settings.title') &&
    //         json['settings.title'] == 'Settings') {
    //       capturedEnContent = json;
    //     } else if (json.containsKey('settings.title') &&
    //         json['settings.title'] == 'Einstellungen') {
    //       capturedDeContent = json;
    //     }
    //   });
    //
    //   testHelper.configureWithArgs([]);
    //   testHelper.createCommand();
    //
    //   testHelper.runGenArb(testBase.mockLibDir.path, mockOutputFile);
    //
    //   expect(capturedEnContent.isNotEmpty, isTrue);
    //   expect(capturedDeContent.isNotEmpty, isTrue);
    //
    //   expect(capturedEnContent, containsPair('settings.title', 'Settings'));
    //   expect(capturedEnContent, containsPair('characters.title', 'Characters'));
    //   expect(capturedEnContent, containsPair('settings.volume', 'Volume'));
    //   expect(capturedEnContent, containsPair('settings.rotation', 'Rotation'));
    //
    //   expect(
    //       capturedDeContent, containsPair('settings.title', 'Einstellungen'));
    //   expect(capturedDeContent, containsPair('characters.title', 'Charaktere'));
    // });

    // test('Alphabetically sorts keys in output ARB files', () {
    //   when(mockArbFiles['en']!.readAsStringSync()).thenReturn(
    //       jsonEncode({'zebra': 'Zebra', 'apple': 'Apple', 'banana': 'Banana'}));
    //
    //   testHelper.testArbFiles = [mockArbFiles['en']!];
    //
    //   final mockOutputFile = MockFile();
    //   String? capturedContent;
    //
    //   when(mockOutputFile.path)
    //       .thenReturn(p.join('/mock/temp', 'lib/l10n/app_en.arb'));
    //   when(mockOutputFile.writeAsStringSync(any)).thenAnswer((invocation) {
    //     capturedContent = invocation.positionalArguments.first as String;
    //   });
    //
    //   testHelper.configureWithArgs([]);
    //   testHelper.createCommand();
    //
    //   testHelper.runGenArb(testBase.mockLibDir.path, mockOutputFile);
    //
    //   expect(capturedContent, isNotNull);
    //   final json = jsonDecode(capturedContent!) as Map<String, dynamic>;
    //
    //   final keys = json.keys.toList();
    //   expect(keys, equals(['apple', 'banana', 'zebra']));
    // });

    test('Flattens nested JSON structures', () {
      testHelper.configureWithArgs([]);
      final command = testHelper.createCommand();

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

    // test('Handles missing translations gracefully', () {
    //   when(mockArbFiles['en']!.readAsStringSync()).thenReturn(jsonEncode({
    //     'settings.title': 'Settings',
    //   }));
    //   when(mockArbFiles['de']!.readAsStringSync()).thenReturn(jsonEncode({
    //     'settings.title': 'Einstellungen',
    //   }));
    //
    //   testHelper.configureWithArgs([]);
    //   testHelper.createCommand();
    //
    //   testHelper.runGenArb(testBase.mockLibDir.path);
    //
    //   verify(mockArbFiles['en']!.readAsStringSync()).called(1);
    //   verify(mockArbFiles['de']!.readAsStringSync()).called(1);
    //   verify(mockNestedFile.readAsStringSync()).called(1);
    // });

    // test('Throws an error if no translations are found', () {
    //   testHelper.testArbFiles = [];
    //
    //   testHelper.configureWithArgs([]);
    //   testHelper.createCommand();
    //
    //   expect(
    //     () => testHelper.runGenArb(testBase.mockLibDir.path),
    //     throwsA(predicate((e) =>
    //         e is Exception &&
    //         e
    //             .toString()
    //             .contains('No .arb files found for supported languages'))),
    //   );
    // });

    // test('Detects and correctly handles key conflicts', () {
    //   final mockConflictFile = MockFile();
    //   when(mockConflictFile.path).thenReturn(p.join(
    //       '/mock/temp', 'features', 'settings', 'l10n', 'en', 'conflicts.arb'));
    //   when(mockConflictFile.existsSync()).thenReturn(true);
    //   when(mockConflictFile.readAsStringSync()).thenReturn(jsonEncode({
    //     'settings.title': 'App Settings',
    //   }));
    //
    //   testHelper.testArbFiles = [...mockArbFileList, mockConflictFile];
    //
    //   final mockOutputFile = MockFile();
    //   Map<String, dynamic>? capturedEnContent;
    //
    //   when(mockOutputFile.path)
    //       .thenReturn(p.join('/mock/temp', 'lib/l10n/app_en.arb'));
    //
    //   int writeCount = 0;
    //   when(mockOutputFile.writeAsStringSync(any)).thenAnswer((invocation) {
    //     final content = invocation.positionalArguments.first as String;
    //     final json = jsonDecode(content) as Map<String, dynamic>;
    //
    //     if (writeCount == 0) {
    //       capturedEnContent = json;
    //     }
    //     writeCount++;
    //   });
    //
    //   testHelper.configureWithArgs([]);
    //   final command = testHelper.createCommand();
    //
    //   testHelper.runGenArb(testBase.mockLibDir.path, mockOutputFile);
    //
    //   expect(capturedEnContent, isNotNull);
    //   expect(capturedEnContent!['settings.title'], equals('Settings'));
    //
    //   final result = command.mergeArbFilesWithConflictDetection(
    //       [mockArbFiles['en']!, mockConflictFile]);
    //
    //   expect(result.conflicts.isNotEmpty, isTrue);
    //   expect(result.conflicts.containsKey('settings.title'), isTrue);
    //   expect(
    //       result.conflicts['settings.title']![0].value, equals('App Settings'));
    //   expect(result.conflicts['settings.title']![0].existingValue,
    //       equals('Settings'));
    // });
  });

  // group('Output generation', () {
  //   test('Writes merged translations to output files', () {
  //     final mockOutputFile = MockFile();
  //     int writeCount = 0;
  //
  //     when(mockOutputFile.path)
  //         .thenReturn(p.join('/mock/temp', 'lib/l10n/app_en.arb'));
  //     when(mockOutputFile.writeAsStringSync(any)).thenAnswer((_) {
  //       writeCount++;
  //     });
  //
  //     testHelper.configureWithArgs([]);
  //     testHelper.createCommand();
  //
  //     testHelper.runGenArb(testBase.mockLibDir.path, mockOutputFile);
  //
  //     expect(writeCount, equals(2));
  //   });
  // });
}
