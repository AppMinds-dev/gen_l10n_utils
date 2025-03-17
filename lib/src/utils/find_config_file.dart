import 'dart:io';
import 'package:path/path.dart' as p;

/// Attempts to load the config file from gen_l10n_utils.yaml
File findConfigFile(String projectRoot, {FileFactory? fileFactory}) {
  fileFactory ??= (path) => File(path);

  final configPath = p.join(projectRoot, 'gen_l10n_utils.yaml');
  final file = fileFactory(configPath);

  if (file.existsSync()) {
    print('✅ Using configuration from ${p.basename(configPath)}');
    return file;
  }

  throw Exception(
      '❌ Missing configuration file. Please create gen_l10n_utils.yaml in your project root.');
}

/// Function type for creating File objects
typedef FileFactory = File Function(String path);