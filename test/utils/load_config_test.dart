import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:gen_l10n_utils/src/utils/load_config.dart';

import 'command_test_base_annotations.mocks.dart';

void main() {
  late MockFile mockConfigFile;

  setUp(() {
    mockConfigFile = MockFile();
    when(mockConfigFile.path).thenReturn('/mock/project/gen_l10n_utils.yaml');
  });

  test('Successfully loads valid config', () {
    when(mockConfigFile.existsSync()).thenReturn(true);
    when(mockConfigFile.readAsStringSync()).thenReturn('''
base_language: en
languages:
  - en
  - de
  - fr
''');

    final config = loadConfig(mockConfigFile);

    expect(config, isA<Map<String, dynamic>>());
    expect(config['base_language'], equals('en'));
    expect(config['languages'], equals(['en', 'de', 'fr']));
    verify(mockConfigFile.existsSync()).called(1);
    verify(mockConfigFile.readAsStringSync()).called(1);
  });

  test('Throws exception when file does not exist', () {
    when(mockConfigFile.existsSync()).thenReturn(false);

    expect(() => loadConfig(mockConfigFile), throwsA(isA<Exception>()));
    verify(mockConfigFile.existsSync()).called(1);
    verifyNever(mockConfigFile.readAsStringSync());
  });

  test('Throws exception for invalid YAML format', () {
    when(mockConfigFile.existsSync()).thenReturn(true);
    when(mockConfigFile.readAsStringSync()).thenReturn('''
invalid:
  - yaml
  format
''');

    expect(() => loadConfig(mockConfigFile), throwsA(isA<Exception>()));
    verify(mockConfigFile.existsSync()).called(1);
    verify(mockConfigFile.readAsStringSync()).called(1);
  });

  test('Throws exception when missing required fields', () {
    when(mockConfigFile.existsSync()).thenReturn(true);
    when(mockConfigFile.readAsStringSync()).thenReturn('''
# Missing base_language field
languages:
  - en
  - de
''');

    expect(() => loadConfig(mockConfigFile), throwsA(isA<Exception>()));
    verify(mockConfigFile.existsSync()).called(1);
    verify(mockConfigFile.readAsStringSync()).called(1);
  });

  test('Throws exception when languages is not a list', () {
    when(mockConfigFile.existsSync()).thenReturn(true);
    when(mockConfigFile.readAsStringSync()).thenReturn('''
base_language: en
languages: not-a-list
''');

    expect(() => loadConfig(mockConfigFile), throwsA(isA<Exception>()));
    verify(mockConfigFile.existsSync()).called(1);
    verify(mockConfigFile.readAsStringSync()).called(1);
  });

  test('Handles empty languages list', () {
    when(mockConfigFile.existsSync()).thenReturn(true);
    when(mockConfigFile.readAsStringSync()).thenReturn('''
base_language: en
languages: []
''');

    final config = loadConfig(mockConfigFile);
    expect(config['languages'], isEmpty);
    verify(mockConfigFile.existsSync()).called(1);
    verify(mockConfigFile.readAsStringSync()).called(1);
  });
}
