import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// Loads supported languages from config file
Map<String, dynamic> loadConfig(File configFile) {
  if (!configFile.existsSync()) {
    throw Exception(
        '❌ Missing configuration file. Please create gen_l10n_utils.yaml in your project root.');
  }

  final config = loadYaml(configFile.readAsStringSync());
  if (config is! Map ||
      config['languages'] is! List ||
      config['base_language'] is! String) {
    throw Exception(
        '❌ Invalid configuration format in ${p.basename(configFile.path)}.');
  }

  return {
    'base_language': config['base_language'],
    'languages': List<String>.from(config['languages']),
  };
}
