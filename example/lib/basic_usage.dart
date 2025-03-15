import 'dart:io';

/// This file demonstrates the basic usage of gen_l10n_utils
void main() async {
  // Step 1: Create a sample project structure
  final projectDir = Directory('sample_project');
  if (!projectDir.existsSync()) {
    projectDir.createSync();
  }

  // Step 2: Create a config file
  final config = '''
default_language: en
languages:
  - en
  - de
  - fr
''';

  File('${projectDir.path}/al10n.yaml')
    ..createSync()
    ..writeAsStringSync(config);

  print('Created config file with languages: en, de, fr');

  // Step 3: Create sample ARB files
  createSampleArbFiles(projectDir.path);

  // Step 4: Run the tool programmatically
  // Note: In real usage, you would typically call these from the command line

  // Print directory structure for debugging
  printDirectoryStructure(projectDir);
}

void createSampleArbFiles(String projectPath) {
  // Create directory structure
  final dirs = [
    'lib/features/home/l10n/en',
    'lib/features/home/l10n/de',
    'lib/features/settings/l10n/en',
    'lib/features/settings/l10n/de',
  ];

  for (var dir in dirs) {
    Directory('$projectPath/$dir').createSync(recursive: true);
  }

  // Create English ARB files
  File('$projectPath/lib/features/home/l10n/en/home.arb')
    ..createSync()
    ..writeAsStringSync('''
{
  "home_title": "Welcome Home",
  "home_greeting": "Hello, {username}!"
}
''');

  File('$projectPath/lib/features/settings/l10n/en/settings.arb')
    ..createSync()
    ..writeAsStringSync('''
{
  "settings": {
    "title": "Settings",
    "appearance": {
      "theme": "Theme",
      "dark_mode": "Dark Mode"
    },
    "notifications": {
      "title": "Notifications",
      "enable": "Enable Notifications"
    }
  }
}
''');

  // Create German ARB files
  File('$projectPath/lib/features/home/l10n/de/home.arb')
    ..createSync()
    ..writeAsStringSync('''
{
  "home_title": "Willkommen",
  "home_greeting": "Hallo, {username}!"
}
''');

  File('$projectPath/lib/features/settings/l10n/de/settings.arb')
    ..createSync()
    ..writeAsStringSync('''
{
  "settings": {
    "title": "Einstellungen",
    "appearance": {
      "theme": "Thema",
      "dark_mode": "Dunkler Modus"
    },
    "notifications": {
      "title": "Benachrichtigungen",
      "enable": "Benachrichtigungen aktivieren"
    }
  }
}
''');

  print('Created sample ARB files in the project directory');
}

void printDirectoryStructure(Directory dir, [String prefix = '']) {
  final entities = dir.listSync();
  for (var i = 0; i < entities.length; i++) {
    final entity = entities[i];
    final isLast = i == entities.length - 1;
    final marker = isLast ? '└── ' : '├── ';

    final entityName = entity.path.split(Platform.pathSeparator).last;
    print('$prefix$marker$entityName');

    if (entity is Directory) {
      final newPrefix = prefix + (isLast ? '    ' : '│   ');
      printDirectoryStructure(entity, newPrefix);
    }
  }
}