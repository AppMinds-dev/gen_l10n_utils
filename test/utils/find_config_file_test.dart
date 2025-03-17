import 'package:test/test.dart';
import 'package:path/path.dart' as p;
import 'package:gen_l10n_utils/src/utils/find_config_file.dart';
import 'package:mockito/mockito.dart';
import 'dart:io';

import 'command_test_base_annotations.mocks.dart';

void main() {
  late MockFile mockConfigFile;
  late String mockProjectRoot;

  setUp(() {
    mockConfigFile = MockFile();
    mockProjectRoot = '/mock/project';

    // Setup gen_l10n_utils.yaml
    when(mockConfigFile.path)
        .thenReturn(p.join(mockProjectRoot, 'gen_l10n_utils.yaml'));
  });

  test('Finds gen_l10n_utils.yaml when it exists', () {
    when(mockConfigFile.existsSync()).thenReturn(true);

    // Create a file factory that returns our mock
    File fileFactory(String path) {
      if (path == p.join(mockProjectRoot, 'gen_l10n_utils.yaml')) {
        return mockConfigFile;
      }
      throw Exception('Unexpected path: $path');
    }

    final result = findConfigFile(mockProjectRoot, fileFactory: fileFactory);
    expect(result, equals(mockConfigFile));
    verify(mockConfigFile.existsSync()).called(1);
  });

  test('Throws exception when config file does not exist', () {
    when(mockConfigFile.existsSync()).thenReturn(false);

    // Create a file factory that returns our mock
    File fileFactory(String path) {
      if (path == p.join(mockProjectRoot, 'gen_l10n_utils.yaml')) {
        return mockConfigFile;
      }
      throw Exception('Unexpected path: $path');
    }

    expect(() => findConfigFile(mockProjectRoot, fileFactory: fileFactory),
        throwsA(isA<Exception>()));
    verify(mockConfigFile.existsSync()).called(1);
  });
}