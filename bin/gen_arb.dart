import 'dart:io';
import 'package:appminds_l10n_tools/appminds_l10n_tools.dart';
import 'package:path/path.dart' as p;

void main() {
  try {
    print('🚀 Running appminds_l10n_tools...');

    // Get project root path
    final projectRoot = Directory.current.path;

    // Locate the config file
    final configFile = File(p.join(projectRoot, 'appminds_l10n.yaml'));
    if (!configFile.existsSync()) {
      throw Exception('❌ Missing appminds_l10n.yaml. Please create it.');
    }

    // Locate `.arb` files within `/lib`
    final libDir = Directory(p.join(projectRoot, 'lib'));
    if (!libDir.existsSync()) {
      throw Exception('❌ lib/ directory not found.');
    }

    final arbFiles = libDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.arb'))
        .toList();

    if (arbFiles.isEmpty) {
      throw Exception('❌ No .arb translation files found in lib/.');
    }

    // Run translation merging
    generateTranslations(projectRoot, configFile, arbFiles);

    print('🎉 Translations merged successfully!');
  } catch (e) {
    print('❌ Error: $e');
    exit(1);
  }
}
