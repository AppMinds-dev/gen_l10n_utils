import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// Loads supported languages from config file
Map<String, dynamic> loadConfig(File configFile) {
  if (!configFile.existsSync()) {
    throw Exception('❌ Missing configuration file. Please create either appminds_l10n.yaml or al10n.yaml.');
  }

  final config = loadYaml(configFile.readAsStringSync());
  if (config is! Map || config['languages'] is! List || config['default_language'] is! String) {
    throw Exception('❌ Invalid configuration format in ${p.basename(configFile.path)}.');
  }

  return {
    'default_language': config['default_language'],
    'languages': List<String>.from(config['languages']),
  };
}