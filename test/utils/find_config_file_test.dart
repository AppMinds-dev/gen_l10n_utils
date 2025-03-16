import 'package:test/test.dart';
import 'package:path/path.dart' as p;
import 'package:gen_l10n_utils/src/utils/find_config_file.dart';
import 'package:mockito/mockito.dart';
import 'dart:io';

import 'command_test_base_annotations.mocks.dart';

void main() {
  late MockFile mockAppmindsConfigFile;
  late MockFile mockAl10nConfigFile;
  late String mockProjectRoot;

  setUp(() {
    mockAppmindsConfigFile = MockFile();
    mockAl10nConfigFile = MockFile();
    mockProjectRoot = '/mock/project';

    // Setup appminds_l10n.yaml
    when(mockAppmindsConfigFile.path)
        .thenReturn(p.join(mockProjectRoot, 'appminds_l10n.yaml'));

    // Setup al10n.yaml
    when(mockAl10nConfigFile.path)
        .thenReturn(p.join(mockProjectRoot, 'al10n.yaml'));
  });

  test('Finds appminds_l10n.yaml when it exists', () {
    // Only appminds_l10n.yaml exists
    when(mockAppmindsConfigFile.existsSync()).thenReturn(true);
    when(mockAl10nConfigFile.existsSync()).thenReturn(false);

    // Create a file factory that returns our mocks
    File fileFactory(String path) {
      if (path == p.join(mockProjectRoot, 'appminds_l10n.yaml')) {
        return mockAppmindsConfigFile;
      } else if (path == p.join(mockProjectRoot, 'al10n.yaml')) {
        return mockAl10nConfigFile;
      }
      throw Exception('Unexpected path: $path');
    }

    final result = findConfigFile(mockProjectRoot, fileFactory: fileFactory);
    expect(result, equals(mockAppmindsConfigFile));
    verify(mockAppmindsConfigFile.existsSync()).called(1);
  });

  test('Finds al10n.yaml when appminds_l10n.yaml is missing', () {
    when(mockAppmindsConfigFile.existsSync()).thenReturn(false);
    when(mockAl10nConfigFile.existsSync()).thenReturn(true);

    // Create a file factory that returns our mocks
    File fileFactory(String path) {
      if (path == p.join(mockProjectRoot, 'appminds_l10n.yaml')) {
        return mockAppmindsConfigFile;
      } else if (path == p.join(mockProjectRoot, 'al10n.yaml')) {
        return mockAl10nConfigFile;
      }
      throw Exception('Unexpected path: $path');
    }

    final result = findConfigFile(mockProjectRoot, fileFactory: fileFactory);
    expect(result, equals(mockAl10nConfigFile));
    verify(mockAppmindsConfigFile.existsSync()).called(1);
    verify(mockAl10nConfigFile.existsSync()).called(1);
  });

  test('Throws exception when no config file exists', () {
    when(mockAppmindsConfigFile.existsSync()).thenReturn(false);
    when(mockAl10nConfigFile.existsSync()).thenReturn(false);

    // Create a file factory that returns our mocks
    File fileFactory(String path) {
      if (path == p.join(mockProjectRoot, 'appminds_l10n.yaml')) {
        return mockAppmindsConfigFile;
      } else if (path == p.join(mockProjectRoot, 'al10n.yaml')) {
        return mockAl10nConfigFile;
      }
      throw Exception('Unexpected path: $path');
    }

    expect(() => findConfigFile(mockProjectRoot, fileFactory: fileFactory),
        throwsA(isA<Exception>()));
    verify(mockAppmindsConfigFile.existsSync()).called(1);
    verify(mockAl10nConfigFile.existsSync()).called(1);
  });
}
