import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:mockito/mockito.dart';

// Import the generated mocks
import 'command_test_base_annotations.mocks.dart';

// Base class for test commands
abstract class TestCommandBase<T extends Command<int>> {
  // Test mode fields
  bool testMode = true;
  File? testFile;
  Directory? testLibDir;
  ArgResults? testArgResults;

  // Factory functions for mocking file operations
  final Function(String) _fileFactory = (String path) => File(path);
  final Function(String) _directoryFactory = (String path) => Directory(path);

  // Override these methods to use mocks
  File? findConfigFile([String? dir]) => testFile;
  Directory getLibDir() => testLibDir ?? Directory('lib');
  File fileNew(String path) => _fileFactory(path);
  Directory directoryNew(String path) => _directoryFactory(path);

  // Configure the command with test arguments
  void configureWithArgs(List<String> args) {
    testArgResults = argParser.parse(args);
  }

  // Access to the command's ArgParser
  ArgParser get argParser;
}

class CommandTestBase {
  // Mock objects that most tests will need
  late MockFile mockConfigFile;
  late MockDirectory mockLibDir;
  late List<MockFile> mockFiles;
  late List<MockDirectory> mockDirs;

  // Setup standard configuration
  void setUp() {
    mockConfigFile = MockFile();
    mockLibDir = MockDirectory();
    mockFiles = List.generate(3, (_) => MockFile());
    mockDirs = List.generate(3, (_) => MockDirectory());

    // Standard config file setup
    when(mockConfigFile.path).thenReturn('al10n.yaml');
    when(mockConfigFile.existsSync()).thenReturn(true);
    when(mockConfigFile.readAsStringSync()).thenReturn('''
base_language: en
languages:
  - en
  - fr
''');

    // Standard lib directory setup
    when(mockLibDir.path).thenReturn('/lib');
    when(mockLibDir.existsSync()).thenReturn(true);
  }

  // Helper to suppress print statements during tests
  Future<T> suppressPrints<T>(Future<T> Function() fn) {
    return runZoned<Future<T>>(
      fn,
      zoneSpecification: ZoneSpecification(
        print: (_, __, ___, ____) {},
      ),
    );
  }

  // Setup file system mocks with typical localization structure
  void setupFileSystem({
    List<String>? languageCodes,
    bool createFiles = true,
  }) {
    languageCodes ??= ['en', 'fr'];

    // Setup mock directories for each language
    for (var i = 0; i < languageCodes.length && i < mockDirs.length; i++) {
      when(mockDirs[i].path).thenReturn('/lib/l10n/${languageCodes[i]}');
      when(mockDirs[i].existsSync()).thenReturn(true);

      if (createFiles) {
        when(mockDirs[i].listSync()).thenReturn([mockFiles[i]]);
        when(mockFiles[i].path)
            .thenReturn('/lib/l10n/${languageCodes[i]}/app.arb');
        when(mockFiles[i].readAsString())
            .thenAnswer((_) => Future.value(jsonEncode({
                  'greeting': 'Hello',
                  'farewell': 'Goodbye',
                  '@greeting': {'description': 'Greeting message'},
                  '@farewell': {'description': 'Farewell message'}
                })));
      } else {
        when(mockDirs[i].listSync()).thenReturn([]);
      }
    }

    // Setup recursive directory listing
    when(mockLibDir.listSync(recursive: true)).thenReturn(mockDirs);
  }

  // Setup a test command with common mocks
  void setupCommand<T extends TestCommandBase>(
    T command,
    List<String> args, {
    bool hasLanguageDirs = true,
  }) {
    command.testFile = mockConfigFile;
    command.testLibDir = mockLibDir;
    command.configureWithArgs(args);

    setupFileSystem(
      createFiles: hasLanguageDirs,
    );
  }
}
