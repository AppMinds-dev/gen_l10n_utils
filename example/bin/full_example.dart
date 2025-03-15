import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:gen_l10n_utils/src/cli/gen_l10n_utils_command_runner.dart';

/// This example shows how to use gen_l10n_utils to manage localization files
void main() async {
  // Create a sample project structure
  final tempDir = Directory.systemTemp.createTempSync('gen_l10n_example_');
  print('Working in temporary directory: ${tempDir.path}');

  // Set up project structure
  createProjectStructure(tempDir.path);

  // Run the commands
  final runner = GenL10nUtilsCommandRunner();

  // Create configuration file
  print('\n1. Creating configuration file...');
  await runner.run(['create-config', '--languages', 'en,de,es', '--default-language', 'en']);

  // Generate ARB files
  print('\n2. Generating ARB files...');
  await runner.run(['gen-arb']);

  // Print results
  print('\n3. Results:');
  final outputDir = Directory(path.join(tempDir.path, 'lib/l10n'));
  if (outputDir.existsSync()) {
    print('Generated files:');
    for (var file in outputDir.listSync()) {
      print('  - ${path.basename(file.path)}');

      if (file is File && file.path.endsWith('.arb')) {
        print('    Content:');
        print('    ${file.readAsStringSync()}');
      }
    }
  } else {
    print('No output files generated.');
  }

  print('\nExample completed! Temporary files are in: ${tempDir.path}');
  print('Delete temporary files? (y/n)');
  final input = stdin.readLineSync();
  if (input?.toLowerCase() == 'y') {
    tempDir.deleteSync(recursive: true);
    print('Temporary files deleted.');
  }
}

void createProjectStructure(String projectPath) {
  print('Setting up project structure...');

  // Create directory structure
  final dirs = [
    'lib/features/auth/l10n/en',
    'lib/features/auth/l10n/de',
    'lib/features/home/l10n/en',
    'lib/features/home/l10n/de',
  ];

  for (var dir in dirs) {
    Directory(path.join(projectPath, dir)).createSync(recursive: true);
  }

  // Create ARB files with nested structures
  // English files
  File(path.join(projectPath, 'lib/features/auth/l10n/en/auth.arb'))
    ..createSync()
    ..writeAsStringSync('''
{
  "auth": {
    "login": "Login",
    "register": "Sign up",
    "forgot_password": "Forgot password?"
  }
}
''');

  File(path.join(projectPath, 'lib/features/home/l10n/en/home.arb'))
    ..createSync()
    ..writeAsStringSync('''
{
  "home": {
    "welcome": "Welcome to the app!",
    "settings": "Settings",
    "profile": "My Profile"
  }
}
''');

  // German files
  File(path.join(projectPath, 'lib/features/auth/l10n/de/auth.arb'))
    ..createSync()
    ..writeAsStringSync('''
{
  "auth": {
    "login": "Anmelden",
    "register": "Registrieren",
    "forgot_password": "Passwort vergessen?"
  }
}
''');

  File(path.join(projectPath, 'lib/features/home/l10n/de/home.arb'))
    ..createSync()
    ..writeAsStringSync('''
{
  "home": {
    "welcome": "Willkommen in der App!",
    "settings": "Einstellungen",
    "profile": "Mein Profil"
  }
}
''');

  print('Project structure created with sample ARB files.');
}