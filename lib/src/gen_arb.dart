import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// Loads supported languages from `appminds_l10n.yaml`
Map<String, dynamic> loadConfig(File configFile) {
  if (!configFile.existsSync()) {
    throw Exception('❌ Missing appminds_l10n.yaml. Please create it.');
  }

  final config = loadYaml(configFile.readAsStringSync());
  if (config is! Map || config['languages'] is! List || config['default_language'] is! String) {
    throw Exception('❌ Invalid appminds_l10n.yaml format.');
  }

  return {
    'default_language': config['default_language'],
    'languages': List<String>.from(config['languages']),
  };
}

/// Generates merged ARB files for supported languages
void genArb(String projectRoot, File configFile, List<File> arbFiles, {File? mockOutputFile}) {
  try {
    final config = loadConfig(configFile);
    final supportedLanguages = config['languages'] as List<String>;

    final outputDir = Directory(p.join(projectRoot, 'l10n'));
    if (!outputDir.existsSync()) {
      outputDir.createSync(recursive: true);
    }

    final Map<String, List<File>> languageFiles = { for (var lang in supportedLanguages) lang: [] };

    for (final file in arbFiles) {
      final langCode = p.basenameWithoutExtension(file.path).split('_').last;
      if (languageFiles.containsKey(langCode)) {
        languageFiles[langCode]!.add(file);
      }
    }

    if (languageFiles.values.every((files) => files.isEmpty)) {
      throw Exception('❌ No .arb files found for supported languages.');
    }

    for (final lang in supportedLanguages) {
      if (languageFiles[lang]!.isNotEmpty) {
        final mergedContent = mergeArbFiles(languageFiles[lang]!);
        final outputFile = mockOutputFile ?? File(p.join(outputDir.path, 'app_$lang.arb'));

        outputFile.writeAsStringSync(
          const JsonEncoder.withIndent("  ").convert(mergedContent),
        );

        print('✅ Translations merged into ${outputFile.path}');
      }
    }
  } catch (e) {
    throw Exception('❌ Error during translation merging: $e');
  }
}

// Keep generateTranslations for backward compatibility
void generateTranslations(String projectRoot, File configFile, List<File> arbFiles, {File? mockOutputFile}) {
  genArb(projectRoot, configFile, arbFiles, mockOutputFile: mockOutputFile);
}

/// Deep merges JSON objects
Map<String, dynamic> deepMerge(Map<String, dynamic> base, Map<String, dynamic> updates) {
  for (final key in updates.keys) {
    if (base.containsKey(key) && base[key] is Map && updates[key] is Map) {
      base[key] = deepMerge(
        Map<String, dynamic>.from(base[key]),
        Map<String, dynamic>.from(updates[key]),
      );
    } else {
      base[key] = updates[key];
    }
  }
  return base;
}

/// Merges multiple .arb files into a single JSON structure
Map<String, dynamic> mergeArbFiles(List<File> arbFiles) {
  final mergedContent = <String, dynamic>{};

  for (final file in arbFiles) {
    final content = file.readAsStringSync();
    try {
      final jsonContent = jsonDecode(content) as Map<String, dynamic>;
      deepMerge(mergedContent, jsonContent);
    } catch (e) {
      throw Exception('❌ Error parsing ${file.path}: $e');
    }
  }

  return mergedContent;
}