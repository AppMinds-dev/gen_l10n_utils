import 'dart:io';
import 'package:args/args.dart';
import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:gen_l10n_utils/src/cli/commands/translate_command.dart';

import '../../utils/command_test_base.dart';
import '../../utils/command_test_base_annotations.mocks.dart';

class TestTranslateCommand extends TestCommandBase<TranslateCommand> {
  @override
  ArgParser get argParser => TranslateCommand().argParser;

  TranslateCommand createCommand() {
    final command = TranslateCommand();
    command.testMode = true;
    command.testArgResults = testArgResults;
    command.testLibDir = testLibDir;
    command.testFile = testFile;
    return command;
  }
}

class TestableTranslateCommand extends TranslateCommand {
  List<FileSystemEntity>? mockListDirResult;
  List<FileSystemEntity> Function(String path)? listDirectoryOverride;
  List<String> Function(String languageCode)? findLanguageDirsOverride;

  @override
  List<FileSystemEntity> listDirectory(String path) {
    if (listDirectoryOverride != null) {
      return listDirectoryOverride!(path);
    }
    if (mockListDirResult != null) {
      return mockListDirResult!;
    }
    return super.listDirectory(path);
  }

  @override
  List<String> findLanguageDirs(String languageCode) {
    if (findLanguageDirsOverride != null) {
      return findLanguageDirsOverride!(languageCode);
    }
    return super.findLanguageDirs(languageCode);
  }
}

class ConfigTestTranslateCommand extends TestableTranslateCommand {
  @override
  Future<void> updateConfigFile(File configFile, String newLanguage,
      List<String> currentLanguages) async {
    configFile.readAsStringSync();
    final updatedLanguages = List<String>.from(currentLanguages)
      ..add(newLanguage);

    final configLines = [
      'base_language: en',
      'languages:',
      ...updatedLanguages.map((lang) => '  - $lang'),
      'output_dir: lib/l10n',
    ].join('\n');

    configFile.writeAsStringSync(configLines);
  }
}

void main() {
  late TestTranslateCommand testHelper;
  late MockFile mockConfigFile;
  late MockDirectory mockLibDir;
  late MockFile mockEnFile;
  late MockFile mockFrFile;
  late MockDirectory mockL10nDir;
  late MockDirectory mockEnDir;
  late MockDirectory mockFrDir;

  setUp(() {
    testHelper = TestTranslateCommand();

    mockConfigFile = MockFile();
    when(mockConfigFile.path).thenReturn('mock/project/gen_l10n_utils.yaml');
    when(mockConfigFile.existsSync()).thenReturn(true);
    when(mockConfigFile.readAsStringSync()).thenReturn('''
base_language: en
languages:
  - en
  - fr
''');

    mockLibDir = MockDirectory();
    when(mockLibDir.path).thenReturn('mock/lib');
    when(mockLibDir.existsSync()).thenReturn(true);

    mockL10nDir = MockDirectory();
    when(mockL10nDir.path).thenReturn('mock/lib/l10n');

    mockEnDir = MockDirectory();
    when(mockEnDir.path).thenReturn('mock/lib/l10n/en');
    when(mockEnDir.existsSync()).thenReturn(true);

    mockFrDir = MockDirectory();
    when(mockFrDir.path).thenReturn('mock/lib/l10n/fr');

    mockEnFile = MockFile();
    mockFrFile = MockFile();

    testHelper.testFile = mockConfigFile;
    testHelper.testLibDir = mockLibDir;
  });

  group('Command validation', () {
    test('Requires language parameter', () async {
      testHelper.configureWithArgs([]);
      final command = testHelper.createCommand();
      final result = await command.run();
      expect(result, equals(1));
    });

    test('Validates supported languages', () async {
      testHelper.configureWithArgs(['--language', 'es']);
      final command = testHelper.createCommand();
      command.testPromptResponse = false;
      final result = await command.run();
      expect(result, equals(1));
    });

    test('Fails when config file is missing', () async {
      testHelper.configureWithArgs(['--language', 'fr']);
      when(mockConfigFile.existsSync()).thenReturn(false);
      final command = testHelper.createCommand();
      final result = await command.run();
      expect(result, equals(1));
    });

    test('Fails when lib directory is missing', () async {
      testHelper.configureWithArgs(['--language', 'fr']);
      when(mockLibDir.existsSync()).thenReturn(false);
      final command = testHelper.createCommand();
      final result = await command.run();
      expect(result, equals(1));
    });
  });

  // group('Translation file updates', () {
  //   test('Updates existing translation file with new keys', () async {
  //     testHelper.configureWithArgs(['--language', 'fr']);
  //
  //     final command = TestableTranslateCommand();
  //     command.testMode = true;
  //     command.testArgResults = testHelper.testArgResults;
  //     command.testLibDir = mockLibDir;
  //     command.testFile = mockConfigFile;
  //
  //     // Source file content
  //     final sourceData = {
  //       'message': 'A new message',
  //       '@message': {
  //         'description': 'A test message'
  //       }
  //     };
  //
  //     // Target file content
  //     final targetData = {
  //       'existingKey': 'Existing translation',
  //       '@existingKey': {
  //         'description': 'Existing description'
  //       }
  //     };
  //
  //     when(mockEnFile.existsSync()).thenReturn(true);
  //     when(mockEnFile.path).thenReturn('mock/lib/l10n/en/app.arb');
  //     when(mockEnFile.readAsStringSync()).thenReturn(jsonEncode(sourceData));
  //
  //     when(mockFrFile.existsSync()).thenReturn(true);
  //     when(mockFrFile.path).thenReturn('mock/lib/l10n/fr/app.arb');
  //     when(mockFrFile.readAsStringSync()).thenReturn(jsonEncode(targetData));
  //
  //     String? capturedContent;
  //     when(mockFrFile.writeAsStringSync(captureAny))
  //         .thenAnswer((inv) => capturedContent = inv.positionalArguments[0]);
  //
  //     command.testCreateFile = (String path) {
  //       if (path.contains('/en/')) return mockEnFile;
  //       return mockFrFile;
  //     };
  //
  //     command.testLanguageDirs = ['mock/lib/l10n/en'];
  //     command.testCreateDir = (String path) {
  //       final dir = MockDirectory();
  //       when(dir.path).thenReturn(path);
  //       when(dir.existsSync()).thenReturn(true);
  //       return dir;
  //     };
  //
  //     final result = await command.run();
  //     expect(result, equals(0));
  //
  //     final Map<String, dynamic> updatedContent = json.decode(capturedContent!);
  //     expect(updatedContent['message'], equals(''));
  //     expect(updatedContent['@message']['description'], equals('A test message'));
  //     expect(updatedContent.containsKey('existingKey'), isFalse);
  //   });
  // });

  group('Directory and cleanup operations', () {
    test('Handles multiple language directories', () async {
      testHelper.configureWithArgs(['--language', 'fr']);

      final command = TestableTranslateCommand();
      command.testMode = true;
      command.testArgResults = testHelper.testArgResults;
      command.testLibDir = mockLibDir;
      command.testFile = mockConfigFile;

      when(mockEnFile.existsSync()).thenReturn(true);
      when(mockEnFile.path).thenReturn('mock/lib/l10n/en/app.arb');
      when(mockEnFile.readAsStringSync()).thenReturn('{"key": "value"}');

      command.testLanguageDirs = ['mock/lib/l10n/en', 'mock/lib/other/en'];

      final processedDirs = <String>[];
      command.testCreateDir = (String path) {
        processedDirs.add(path.replaceAll(r'\', '/'));
        final dir = MockDirectory();
        when(dir.path).thenReturn(path);
        when(dir.existsSync()).thenReturn(true);
        when(dir.listSync()).thenReturn([mockEnFile]);
        return dir;
      };

      command.testCreateFile = (String path) => mockEnFile;

      await command.run();

      expect(processedDirs, contains('mock/lib/l10n/fr'));
      expect(processedDirs, contains('mock/lib/other/fr'));
    });
  });
}
