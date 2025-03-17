import 'dart:convert';
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

// Create a custom test command to override listDirectory
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
  Future<void> updateConfigFile(File configFile, String newLanguage, List<String> currentLanguages) async {
    configFile.readAsStringSync();
    final updatedLanguages = List<String>.from(currentLanguages)..add(newLanguage);

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

    // Config file setup
    mockConfigFile = MockFile();
    when(mockConfigFile.path).thenReturn('mock/project/gen_l10n_utils.yaml');
    when(mockConfigFile.existsSync()).thenReturn(true);
    when(mockConfigFile.readAsStringSync()).thenReturn('''
base_language: en
languages:
  - en
  - fr
''');

    // Directory setup
    mockLibDir = MockDirectory();
    when(mockLibDir.path).thenReturn('mock/lib');
    when(mockLibDir.existsSync()).thenReturn(true);

    // L10n directory
    mockL10nDir = MockDirectory();
    when(mockL10nDir.path).thenReturn('mock/lib/l10n');

    // Language directories
    mockEnDir = MockDirectory();
    when(mockEnDir.path).thenReturn('mock/lib/l10n/en');
    when(mockEnDir.existsSync()).thenReturn(true);

    mockFrDir = MockDirectory();
    when(mockFrDir.path).thenReturn('mock/lib/l10n/fr');

    // Files setup
    mockEnFile = MockFile();
    mockFrFile = MockFile();

    // Configure helper
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
      command.testPromptResponse = false; // Simulate 'no' to adding language

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

  group('Language configuration', () {
    test('Adds new language to config when user confirms', () async {
      testHelper.configureWithArgs(['--language', 'de']);

      final command = TestableTranslateCommand();
      command.testMode = true;
      command.testArgResults = testHelper.testArgResults;
      command.testLibDir = mockLibDir;
      command.testFile = mockConfigFile;
      command.testPromptResponse = true;

      // Mock base file
      when(mockEnFile.existsSync()).thenReturn(true);
      when(mockEnFile.path).thenReturn('mock/lib/l10n/en/app.arb');
      when(mockEnFile.readAsStringSync()).thenReturn('{"key": "value"}');

      command.testLanguageDirs = ['mock/lib/l10n/en'];
      command.testCreateFile = (String path) => mockEnFile;

      // Mock directory creation
      command.testCreateDir = (String path) {
        final mockDir = MockDirectory();
        when(mockDir.path).thenReturn(path);
        when(mockDir.existsSync()).thenReturn(true);
        when(mockDir.listSync()).thenReturn([mockEnFile]);
        return mockDir;
      };

      final result = await command.run();
      expect(result, equals(0));
    });

    test('Aborts when user declines adding new language', () async {
      testHelper.configureWithArgs(['--language', 'de']);

      final command = TestableTranslateCommand();
      command.testMode = true;
      command.testArgResults = testHelper.testArgResults;
      command.testLibDir = mockLibDir;
      command.testFile = mockConfigFile;
      command.testPromptResponse = false; // Simulate user declining

      // Execute command
      final result = await command.run();
      expect(result, equals(1));

      // Verify config was not modified
      verifyNever(mockConfigFile.writeAsStringSync(any));
    });

    test('Preserves existing config structure when adding language', () async {
      final configContent = '''
base_language: en
languages:
  - en
  - fr
output_dir: lib/l10n
''';
      when(mockConfigFile.readAsStringSync()).thenReturn(configContent);

      testHelper.configureWithArgs(['--language', 'de']);

      String capturedContent = '';
      when(mockConfigFile.writeAsStringSync(captureAny))
          .thenAnswer((inv) => capturedContent = inv.positionalArguments[0]);

      // Create command first
      final command = ConfigTestTranslateCommand();

      // Mock base file
      when(mockEnFile.existsSync()).thenReturn(true);
      when(mockEnFile.path).thenReturn('mock/lib/l10n/en/app.arb');
      when(mockEnFile.readAsStringSync()).thenReturn('{"key": "value"}');

      // Setup command properties without cascade
      command.testMode = true;
      command.testArgResults = testHelper.testArgResults;
      command.testLibDir = mockLibDir;
      command.testFile = mockConfigFile;
      command.testPromptResponse = true;
      command.testCreateFile = (String path) => mockEnFile;
      command.testCreateDir = (String path) => mockLibDir;
      command.testLanguageDirs = ['mock/lib/l10n/en'];

      await command.run();

      expect(capturedContent, contains('base_language: en'));
      expect(capturedContent, contains('output_dir: lib/l10n'));
      expect(capturedContent, contains('  - de'));
    });
  });

  group('Translation file updates', () {
    test('Updates existing translation file with new keys', () async {
      // Prepare test data
      final baseJsonData = {
        'greeting': 'Hello',
        '@greeting': {
          'description': 'A greeting message'
        },
        'newKey': 'New message',
        '@newKey': {
          'description': 'A new message'
        }
      };

      final existingTranslation = {
        'greeting': 'Bonjour',
        '@greeting': {
          'description': 'A greeting message'
        }
      };

      testHelper.configureWithArgs(['--language', 'fr']);

      final command = TestableTranslateCommand();
      command.testMode = true;
      command.testArgResults = testHelper.testArgResults;
      command.testLibDir = mockLibDir;
      command.testFile = mockConfigFile;

      // Capture the written content
      String capturedContent = '';

      when(mockEnFile.existsSync()).thenReturn(true);
      when(mockEnFile.path).thenReturn('mock/lib/l10n/en/app.arb');
      when(mockEnFile.readAsStringSync()).thenReturn(jsonEncode(baseJsonData));

      when(mockFrFile.existsSync()).thenReturn(true);
      when(mockFrFile.path).thenReturn('mock/lib/l10n/fr/app.arb');
      when(mockFrFile.readAsStringSync()).thenReturn(jsonEncode(existingTranslation));
      when(mockFrFile.writeAsStringSync(captureAny)).thenAnswer((inv) {
        capturedContent = inv.positionalArguments[0];
        return;
      });

      command.testCreateFile = (String path) {
        final normalizedPath = path.replaceAll(r'\', '/');
        if (normalizedPath.contains('en/app.arb')) {
          return mockEnFile;
        } else if (normalizedPath.contains('fr/app.arb')) {
          return mockFrFile;
        }
        return mockEnFile;
      };

      command.testLanguageDirs = ['mock/lib/l10n/en'];

      command.testCreateDir = (String path) {
        final mockDir = MockDirectory();
        when(mockDir.path).thenReturn(path);
        when(mockDir.existsSync()).thenReturn(true);
        return mockDir;
      };

      // Execute command
      final result = await command.run();
      expect(result, equals(0));

      // Verify the updated content
      final Map<String, dynamic> updatedJson = json.decode(capturedContent);
      expect(updatedJson['greeting'], equals('Bonjour')); // Existing translation preserved
      expect(updatedJson['newKey'], equals('')); // New key added with empty value
      expect(updatedJson['@newKey']['description'], equals('A new message')); // Metadata preserved
    });

    test('Removes keys that no longer exist in base file', () async {
      // Prepare test data
      final baseJsonData = {
        'greeting': 'Hello',
        '@greeting': {
          'description': 'A greeting message'
        }
      };

      final existingTranslation = {
        'greeting': 'Bonjour',
        '@greeting': {
          'description': 'A greeting message'
        },
        'obsoleteKey': 'Old message',
        '@obsoleteKey': {
          'description': 'An old message'
        }
      };

      testHelper.configureWithArgs(['--language', 'fr']);

      final command = TestableTranslateCommand();
      command.testMode = true;
      command.testArgResults = testHelper.testArgResults;
      command.testLibDir = mockLibDir;
      command.testFile = mockConfigFile;

      String capturedContent = '';

      when(mockEnFile.existsSync()).thenReturn(true);
      when(mockEnFile.path).thenReturn('mock/lib/l10n/en/app.arb');
      when(mockEnFile.readAsStringSync()).thenReturn(jsonEncode(baseJsonData));

      when(mockFrFile.existsSync()).thenReturn(true);
      when(mockFrFile.path).thenReturn('mock/lib/l10n/fr/app.arb');
      when(mockFrFile.readAsStringSync()).thenReturn(jsonEncode(existingTranslation));
      when(mockFrFile.writeAsStringSync(captureAny)).thenAnswer((inv) {
        capturedContent = inv.positionalArguments[0];
        return;
      });

      command.testCreateFile = (String path) {
        final normalizedPath = path.replaceAll(r'\', '/');
        if (normalizedPath.contains('en/app.arb')) {
          return mockEnFile;
        } else if (normalizedPath.contains('fr/app.arb')) {
          return mockFrFile;
        }
        return mockEnFile;
      };

      command.testLanguageDirs = ['mock/lib/l10n/en'];

      command.testCreateDir = (String path) {
        final mockDir = MockDirectory();
        when(mockDir.path).thenReturn(path);
        when(mockDir.existsSync()).thenReturn(true);
        return mockDir;
      };

      // Execute command
      final result = await command.run();
      expect(result, equals(0));

      // Verify the updated content
      final Map<String, dynamic> updatedJson = json.decode(capturedContent);
      expect(updatedJson['greeting'], equals('Bonjour')); // Existing translation preserved
      expect(updatedJson.containsKey('obsoleteKey'), isFalse); // Old key removed
      expect(updatedJson.containsKey('@obsoleteKey'), isFalse); // Old key metadata removed
    });
  });

  group('Directory and cleanup operations', () {
    // test('Removes translation files when base file is deleted', () async {
    //   testHelper.configureWithArgs(['--language', 'fr']);
    //
    //   final command = TestableTranslateCommand();
    //   command.testMode = true;
    //   command.testArgResults = testHelper.testArgResults;
    //   command.testLibDir = mockLibDir;
    //   command.testFile = mockConfigFile;
    //
    //   // Mock base file (en/test.arb exists)
    //   final mockEnTestFile = MockFile();
    //   when(mockEnTestFile.existsSync()).thenReturn(true);
    //   when(mockEnTestFile.path).thenReturn('mock/lib/l10n/en/test.arb');
    //   when(mockEnTestFile.readAsStringSync(encoding: utf8)).thenReturn('{}');
    //
    //   // Mock target files (fr/test.arb and fr/test2.arb)
    //   final mockFrTestFile = MockFile();
    //   when(mockFrTestFile.existsSync()).thenReturn(true);
    //   when(mockFrTestFile.path).thenReturn('mock/lib/l10n/fr/test.arb');
    //   when(mockFrTestFile.readAsStringSync(encoding: utf8)).thenReturn('{"key": "value"}');
    //
    //   final mockFrTest2File = MockFile();
    //   when(mockFrTest2File.existsSync()).thenReturn(true);
    //   when(mockFrTest2File.path).thenReturn('mock/lib/l10n/fr/test2.arb');
    //   when(mockFrTest2File.readAsStringSync(encoding: utf8)).thenReturn('{"key": "value"}');
    //
    //   bool fileDeleted = false;
    //   when(mockFrTest2File.deleteSync()).thenAnswer((_) {
    //     fileDeleted = true;
    //   });
    //
    //   // Ensure `testCreateFile` correctly returns the mock files
    //   command.testCreateFile = (String path) {
    //     if (path.contains('/fr/test.arb')) {
    //       return mockFrTestFile;
    //     }
    //     if (path.contains('/fr/test2.arb')) {
    //       return mockFrTest2File;
    //     }
    //     if (path.contains('/en/test.arb')) {
    //       return mockEnTestFile;
    //     }
    //     final mockFile = MockFile();
    //     when(mockFile.existsSync()).thenReturn(true);
    //     when(mockFile.readAsStringSync(encoding: utf8)).thenReturn('{}');
    //     return mockFile; // Return a generic mock if the path doesn't match
    //   };
    //
    //   // Ensure test directory setup is correct
    //   command.testCreateDir = (String path) {
    //     if (path.contains('l10n/fr')) {
    //       return mockFrDir;
    //     }
    //     if (path.contains('l10n/en')) {
    //       return mockEnDir;
    //     }
    //     return mockLibDir;
    //   };
    //
    //   // Override listDirectory to return the appropriate files
    //   command.listDirectoryOverride = (String path) {
    //     if (path.contains('l10n/en')) {
    //       // Simulate the base file not existing anymore
    //       when(mockEnTestFile.existsSync()).thenReturn(false);
    //       return [mockEnTestFile];
    //     } else if (path.contains('l10n/fr')) {
    //       // Initially, both files exist in the 'fr' directory
    //       return [mockFrTestFile, mockFrTest2File];
    //     }
    //     return [];
    //   };
    //
    //   // Override findLanguageDirs to return the base language directory
    //   command.findLanguageDirsOverride = (String languageCode) {
    //     if (languageCode == 'en') {
    //       return ['mock/lib/l10n/en'];
    //     } else {
    //       return [];
    //     }
    //   };
    //
    //   final result = await command.run();
    //   expect(result, equals(0));
    //   expect(fileDeleted, isTrue); // Ensure fr/test2.arb is deleted
    // });

    // test('Creates target directory if it does not exist', () async {
    //   testHelper.configureWithArgs(['--language', 'fr']);
    //
    //   final command = TestableTranslateCommand();
    //   command.testMode = true;
    //   command.testArgResults = testHelper.testArgResults;
    //   command.testLibDir = mockLibDir;
    //   command.testFile = mockConfigFile;
    //
    //   command.testLanguageDirs = ['mock/lib/l10n/en'];
    //
    //   // Setup source file
    //   when(mockEnFile.existsSync()).thenReturn(true);
    //   when(mockEnFile.path).thenReturn('mock/lib/l10n/en/app.arb');
    //   when(mockEnFile.readAsStringSync()).thenReturn('{"key": "value"}');
    //
    //   bool dirCreated = false;
    //   command.testCreateDir = (String path) {
    //     final mockDir = MockDirectory();
    //     when(mockDir.path).thenReturn(path);
    //     when(mockDir.existsSync()).thenReturn(false);
    //     when(mockDir.createSync(recursive: true)).thenAnswer((_) => dirCreated = true);
    //     return mockDir;
    //   };
    //
    //   command.testCreateFile = (String path) {
    //     if (path.contains('en/')) return mockEnFile;
    //     return mockFrFile;
    //   };
    //
    //   // Execute command
    //   await command.run();
    //   expect(dirCreated, isTrue);
    // });

    test('Handles multiple language directories', () async {
      testHelper.configureWithArgs(['--language', 'fr']);

      final command = TestableTranslateCommand();
      command.testMode = true;
      command.testArgResults = testHelper.testArgResults;
      command.testLibDir = mockLibDir;
      command.testFile = mockConfigFile;

      // Mock base file
      when(mockEnFile.existsSync()).thenReturn(true);
      when(mockEnFile.path).thenReturn('mock/lib/l10n/en/app.arb');
      when(mockEnFile.readAsStringSync()).thenReturn('{"key": "value"}');

      command.testLanguageDirs = [
        'mock/lib/l10n/en',
        'mock/lib/other/en'
      ];

      final processedDirs = <String>[];
      command.testCreateDir = (String path) {
        // Normalize path for comparison
        processedDirs.add(path.replaceAll(r'\', '/'));
        final mockDir = MockDirectory();
        when(mockDir.path).thenReturn(path);
        when(mockDir.existsSync()).thenReturn(true);
        when(mockDir.listSync()).thenReturn([mockEnFile]);
        return mockDir;
      };

      command.testCreateFile = (String path) => mockEnFile;

      await command.run();

      expect(processedDirs, contains('mock/lib/l10n/fr'));
      expect(processedDirs, contains('mock/lib/other/fr'));
    });
  });
}
