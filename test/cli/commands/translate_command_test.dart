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

  @override
  List<FileSystemEntity> listDirectory(String path) {
    if (mockListDirResult != null) {
      return mockListDirResult!;
    }
    return super.listDirectory(path);
  }
}

void main() {
  late TestTranslateCommand testHelper;
  late MockFile mockConfigFile;
  late MockDirectory mockLibDir;
  late MockFile mockEnFile;
  late MockFile mockFrFile;
  late MockDirectory mockL10nDir;

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

    // Files setup
    mockEnFile = MockFile();
    mockFrFile = MockFile();

    // Configure helper
    testHelper.testFile = mockConfigFile;
    testHelper.testLibDir = mockLibDir;
  });

  group('Translation file creation', () {
    test('Creates empty translation file for new language', () async {
      // Prepare test data
      final jsonData = {
        'greeting': 'Hello',
        '@greeting': {
          'description': 'A greeting message',
          'placeholders': {
            'name': {'type': 'String', 'example': 'John'}
          }
        }
      };

      // Configure command
      testHelper.configureWithArgs(['--language', 'fr']);

      final command = TestableTranslateCommand();
      command.testMode = true;
      command.testArgResults = testHelper.testArgResults;
      command.testLibDir = mockLibDir;
      command.testFile = mockConfigFile;

      // Capture the written content for verification
      String capturedContent = '';

      when(mockEnFile.existsSync()).thenReturn(true);
      when(mockEnFile.path).thenReturn('mock/lib/l10n/en/app.arb');
      when(mockEnFile.readAsStringSync()).thenReturn(jsonEncode(jsonData));

      when(mockFrFile.existsSync()).thenReturn(false);
      when(mockFrFile.path).thenReturn('mock/lib/l10n/fr/app.arb');
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
        return mockEnFile; // Default to English file to avoid errors
      };

      command.testLanguageDirs = ['mock/lib/l10n/en'];

      // Stub directories with proper path implementation
      command.testCreateDir = (String path) {
        final mockDir = MockDirectory();
        when(mockDir.path).thenReturn(path);
        when(mockDir.existsSync()).thenReturn(true);
        when(mockDir.createSync(recursive: true)).thenReturn(null);
        return mockDir;
      };

      // Execute and verify
      final result = await command.run();
      expect(result, equals(0));

      // Verify content structure without requiring exact strings
      expect(capturedContent, contains('"greeting":""'));
      expect(capturedContent, contains('"description":"A greeting message"'));
    });
  });
}
