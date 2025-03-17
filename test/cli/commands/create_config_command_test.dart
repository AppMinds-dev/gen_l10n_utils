import 'dart:async';

import 'package:args/args.dart';
import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:gen_l10n_utils/src/cli/commands/create_config_command.dart';

import '../../utils/command_test_base.dart';

class TestCreateConfigCommand extends TestCommandBase<CreateConfigCommand> {
  @override
  ArgParser get argParser => CreateConfigCommand().argParser;

  late CreateConfigCommand command;
  bool userInput = false;

  CreateConfigCommand createCommand() {
    command = CreateConfigCommand();
    command.testMode = true;
    command.testArgResults = testArgResults;
    command.testFile = testFile;
    command.testUserInput = userInput;
    return command;
  }
}

void main() {
  late CommandTestBase testBase;
  late TestCreateConfigCommand testHelper;

  setUp(() {
    testBase = CommandTestBase();
    testBase.setUp();

    // Mock the config file using the correct method
    testBase.mockConfigFile = testBase.setupMockFile('gen_l10n_utils.yaml');
    testHelper = TestCreateConfigCommand();
    testHelper.testFile = testBase.mockConfigFile;

    // Properly stub writeAsString to return a Future<File>
    when(testBase.mockConfigFile.writeAsString(any))
        .thenAnswer((_) => Future.value(testBase.mockConfigFile));

    // Add stub for readAsStringSync to return valid YAML
    when(testBase.mockConfigFile.readAsStringSync()).thenReturn('''
base_language: en
languages:
  - en
  - fr
''');
  });

  group('Command configuration', () {
    late CreateConfigCommand command;

    setUp(() {
      command = CreateConfigCommand();
    });

    test('Has correct name and description', () {
      expect(command.name, equals('create-config'));
      expect(command.description, isNotEmpty);
    });

    test('Uses correct config file name', () {
      expect(CreateConfigCommand.configFileName, equals('gen_l10n_utils.yaml'));
    });

    test('Has required arguments configured', () {
      final argParser = command.argParser;
      expect(argParser.options.containsKey('base-language'), isTrue);
      expect(argParser.options.containsKey('languages'), isTrue);
    });

    test('Has correct default values', () {
      final argParser = command.argParser;
      expect(argParser.options['base-language']?.defaultsTo, equals('en'));
      expect(argParser.options['languages']?.defaultsTo, equals(['en']));
    });
  });

  group('File creation and updates', () {
    test('Creates new config file when none exists', () async {
      when(testBase.mockConfigFile.existsSync()).thenReturn(false);
      when(testBase.mockConfigFile.path).thenReturn('gen_l10n_utils.yaml');

      testHelper
          .configureWithArgs(['--base-language', 'en', '--languages', 'en,de']);
      final command = testHelper.createCommand();

      final result = await testBase.suppressPrints(() => command.run());
      expect(result, equals(0));

      final expectedContent = '''base_language: en
languages:
  - en
  - de
''';
      verify(testBase.mockConfigFile.writeAsString(expectedContent)).called(1);
    });

    test('Updates existing config file when confirmed', () async {
      when(testBase.mockConfigFile.existsSync()).thenReturn(true);
      when(testBase.mockConfigFile.path).thenReturn('gen_l10n_utils.yaml');

      testHelper
          .configureWithArgs(['--base-language', 'fr', '--languages', 'fr,es']);
      testHelper.userInput = true;

      final command = testHelper.createCommand();
      final result = await testBase.suppressPrints(() => command.run());

      expect(result, equals(0));
      verify(testBase.mockConfigFile.readAsStringSync()).called(1);
      verify(testBase.mockConfigFile.writeAsString(any)).called(1);
    });

    test('Cancels update when user declines', () async {
      when(testBase.mockConfigFile.existsSync()).thenReturn(true);
      when(testBase.mockConfigFile.path).thenReturn('gen_l10n_utils.yaml');

      testHelper
          .configureWithArgs(['--base-language', 'fr', '--languages', 'fr,es']);
      testHelper.userInput = false;

      final command = testHelper.createCommand();
      final result = await testBase.suppressPrints(() => command.run());

      expect(result, equals(1));
      verifyNever(testBase.mockConfigFile.writeAsString(any));
    });

    test('Creates config with custom language settings', () async {
      when(testBase.mockConfigFile.existsSync()).thenReturn(false);
      when(testBase.mockConfigFile.path).thenReturn('gen_l10n_utils.yaml');

      testHelper.configureWithArgs(
          ['--base-language', 'de', '--languages', 'de,en,es']);
      final command = testHelper.createCommand();

      final result = await testBase.suppressPrints(() => command.run());
      expect(result, equals(0));

      final expectedContent = '''base_language: de
languages:
  - de
  - en
  - es
''';
      verify(testBase.mockConfigFile.writeAsString(expectedContent)).called(1);
    });

    test('Ensures base language is included in languages list', () async {
      when(testBase.mockConfigFile.existsSync()).thenReturn(false);
      when(testBase.mockConfigFile.path).thenReturn('gen_l10n_utils.yaml');

      testHelper.configureWithArgs(
          ['--base-language', 'fr', '--languages', 'de,en,es']);
      final command = testHelper.createCommand();

      final result = await testBase.suppressPrints(() => command.run());
      expect(result, equals(0));

      final expectedContent = '''base_language: fr
languages:
  - fr
  - de
  - en
  - es
''';
      verify(testBase.mockConfigFile.writeAsString(expectedContent)).called(1);
    });
  });
}