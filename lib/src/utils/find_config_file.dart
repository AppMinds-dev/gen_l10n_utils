import 'dart:io';
import 'package:path/path.dart' as p;

/// Attempts to load the config file from either appminds_l10n.yaml or al10n.yaml
File findConfigFile(String projectRoot, {FileFactory? fileFactory}) {
  fileFactory ??= (path) => File(path);

  final configPaths = [
    p.join(projectRoot, 'appminds_l10n.yaml'),
    p.join(projectRoot, 'al10n.yaml'),
  ];

  for (final path in configPaths) {
    final file = fileFactory(path);
    if (file.existsSync()) {
      print('✅ Using configuration from ${p.basename(path)}');
      return file;
    }
  }

  throw Exception('❌ Missing configuration file. Please create either appminds_l10n.yaml or al10n.yaml.');
}

/// Function type for creating File objects
typedef FileFactory = File Function(String path);