import 'dart:io';
import 'package:path/path.dart' as p;

/// Attempts to load the config file from either appminds_l10n.yaml or al10n.yaml
File findConfigFile(String projectRoot) {
  final configPaths = [
    p.join(projectRoot, 'appminds_l10n.yaml'),
    p.join(projectRoot, 'al10n.yaml'),
  ];

  for (final path in configPaths) {
    final file = File(path);
    if (file.existsSync()) {
      print('✅ Using configuration from ${p.basename(path)}');
      return file;
    }
  }

  throw Exception('❌ Missing configuration file. Please create either appminds_l10n.yaml or al10n.yaml.');
}