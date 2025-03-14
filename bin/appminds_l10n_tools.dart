import 'dart:io';
import 'package:appminds_l10n_tools/appminds_l10n_tools.dart';
import 'package:path/path.dart' as p;

void main(List<String> args) {
  if (args.isEmpty) {
    printUsage();
    exit(1);
  }

  final command = args[0];
  switch (command) {
    case 'gen_arb':
      runGenArb();
      break;
    case '--help':
    case '-h':
    case 'help':
      printUsage();
      break;
    default:
      print('❌ Unknown command: $command');
      printUsage();
      exit(1);
  }
}

void printUsage() {
  print('AppMinds L10n Tools');
  print('Usage:');
  print('  dart run appminds_l10n_tools <command>');
  print('\nCommands:');
  print('  gen_arb    Generate merged ARB files from source translations');
  print('  help       Show this usage information');
  print('\nShortcuts:');
  print('  You can use "al10n" instead of "appminds_l10n_tools"');
}

void runGenArb() {
  try {
    print('🚀 Generating ARB files...');

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
    genArb(projectRoot, configFile, arbFiles);

    print('🎉 ARB files generated successfully!');
  } catch (e) {
    print('❌ Error: $e');
    exit(1);
  }
}