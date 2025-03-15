import 'dart:io';
import 'dart:async';

import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';
import 'package:gen_l10n_utils/src/cli/commands/create_config_command.dart';

import 'create_config_command_test.mocks.dart';

@GenerateMocks([File])
void main() {
  late CreateConfigCommand command;
  late MockFile mockConfigFile;

  Future<T> suppressPrints<T>(Future<T> Function() fn) {
    return runZoned<Future<T>>(
      fn,
      zoneSpecification: ZoneSpecification(
        print: (_, __, ___, ____) {},
      ),
    );
  }

  void setupCommand(List<String> args, {bool fileExists = false}) {
    command = CreateConfigCommand();
    command.testMode = true;
    command.testArgResults = command.argParser.parse(args);

    // Set testFile only when fileExists is true
    // This matches the behavior in the real code where findConfigFile
    // returns null or throws when no file exists
    if (fileExists) {
      command.testFile = mockConfigFile;
    } else {
      command.testFile = null;
    }

    when(mockConfigFile.path).thenReturn('al10n.yaml');
    when(mockConfigFile.existsSync()).thenReturn(fileExists);
    when(mockConfigFile.readAsStringSync()).thenReturn('''
default_language: en
languages:
  - en
  - de
''');
    when(mockConfigFile.writeAsString(any))
        .thenAnswer((_) => Future.value(mockConfigFile));
  }

  setUp(() {
    mockConfigFile = MockFile();
  });

  group('Command configuration', () {
    setUp(() {
      command = CreateConfigCommand();
    });

    test('Has correct name and description', () {
      expect(command.name, equals('create-config'));
      expect(command.description, isNotEmpty);
    });

    test('Has required arguments configured', () {
      final argParser = command.argParser;
      expect(argParser.options.containsKey('default-language'), isTrue);
      expect(argParser.options.containsKey('languages'), isTrue);
      expect(argParser.options.containsKey('output'), isFalse);
    });

    test('Has correct default values', () {
      final argParser = command.argParser;
      expect(argParser.options['default-language']?.defaultsTo, equals('en'));
      expect(argParser.options['languages']?.defaultsTo, equals(['en']));
    });
  });

  group('File creation and updates', () {
    test('Creates new config file when none exists', () async {
      // Setup command with no existing file
      setupCommand(['--default-language', 'en', '--languages', 'en,de'],
          fileExists: false);

      // For new file creation, we need to provide the file that will be created
      command.testFile = mockConfigFile;

      final result = await suppressPrints(() async => await command.run());

      expect(result, equals(0));
      verify(mockConfigFile.writeAsString(any)).called(1);
    });

    test('Prompts for update when file exists and updates when confirmed',
        () async {
      setupCommand(['--default-language', 'fr', '--languages', 'fr,es'],
          fileExists: true);
      command.testUserInput = true;

      final result = await suppressPrints(() async => await command.run());

      expect(result, equals(0));
      verify(mockConfigFile.readAsStringSync()).called(1);
      verify(mockConfigFile.writeAsString(any)).called(1);
    });

    test('Cancels update when user declines', () async {
      setupCommand(['--default-language', 'fr', '--languages', 'fr,es'],
          fileExists: true);
      command.testUserInput = false;

      final result = await suppressPrints(() async => await command.run());

      expect(result, equals(1));
      verifyNever(mockConfigFile.writeAsString(any));
    });

    test('Creates config with custom language settings', () async {
      // Setup command with no existing file
      setupCommand(['--default-language', 'de', '--languages', 'de,en,es'],
          fileExists: false);

      // For new file creation, we need to provide the file that will be created
      command.testFile = mockConfigFile;

      final result = await suppressPrints(() async => await command.run());

      expect(result, equals(0));

      final captured =
          verify(mockConfigFile.writeAsString(captureAny)).captured;
      expect(captured.first, contains('default_language: de'));
    });

    test('Ensures default language is in languages list', () async {
      // Setup command with no existing file
      setupCommand(['--default-language', 'fr', '--languages', 'de,en,es'],
          fileExists: false);

      // For new file creation, we need to provide the file that will be created
      command.testFile = mockConfigFile;

      final result = await suppressPrints(() async => await command.run());

      expect(result, equals(0));

      final captured =
          verify(mockConfigFile.writeAsString(captureAny)).captured;
      expect(captured.first, contains('default_language: fr'));
      expect(captured.first, contains('- fr'));
    });
  });
}
