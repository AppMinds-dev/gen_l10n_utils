# gen_l10n_utils

A command-line utility for managing Flutter app localizations with enhanced features for metadata handling and export capabilities.

## Features

- Find and merge ARB files from multiple directories
- Generate simplified ARB files for Flutter localization
- Generate metadata-rich ARB files for export
- Export to XLIFF format with full metadata preservation
- Automatic conflict detection and resolution
- Support for nested JSON structures
- Configurable via YAML

## Installation

Add the package to your `pubspec.yaml` file:

```yaml
dev_dependencies:
  gen_l10n_utils: ^1.2.0
```

Or install it globally:

```bash
dart pub global activate gen_l10n_utils
```

## Commands

### Creating Configuration `gen_l10n_utils create-config`

```bash
dart run gen_l10n_utils create-config
```

This command:
- Creates a configuration file (`gen_l10n_utils.yaml`) in your project root
- Allows you to specify supported languages and export preferences
- Sets up the base configuration for the tool

### Translating Files `gen_l10n_utils translate`

```bash
# Translate all languages
dart run gen_l10n_utils translate
# or
dart run gen_l10n_utils translate --language fr
# or
dart run gen_l10n_utils translate -l fr
```

This command:
- Creates or updates translation files for a specific language based on the base language
- Adds missing keys from the base language to the target language files
- Removes keys from the target language files that no longer exist in the base language files
- Can automatically add the language to the config file if not already present
- Displays the language currently being processed in the console output

Options:
- `--language` or `-l`: The language code to create translations for (optional)

### Generating ARB Files `gen_l10n_utils gen-arb`

```bash
dart run gen_l10n_utils gen-arb
```

This command:
- Finds all .arb files in your project
- Detects languages based on directory paths
- Generates two versions of ARB files for each language:
    1. Simplified version (`app_*.arb`) with just translations
    2. Metadata version (`metadata/app_*_metadata.arb`) with full metadata structure
- Merges translations into combined ARB files in the `lib/l10n` directory
- Detects duplicate keys within each language and resolves conflicts (first occurrence wins)

Example output structure:
```
lib/l10n/
├── app_en.arb           # Simplified English translations
├── app_de.arb           # Simplified German translations
└── metadata/
    ├── app_en_metadata.arb  # English with metadata
    └── app_de_metadata.arb  # German with metadata
```

Example input ARB file with metadata:
```json
{
  "@greeting.description": "A welcome message with the user's name",
  "@greeting.placeholders.username.description": "The user's display name",
  "@greeting.placeholders.username.example": "John Doe",
  "@greeting.placeholders.username.type": "String",
  "greeting": "Welcome, {username}!"
}
```

Generated simplified ARB (`app_en.arb`):
```json
{
  "greeting": "Welcome, {username}!"
}
```

Generated metadata ARB (`metadata/app_en_metadata.arb`):
```json
{
  "greeting": "Welcome, {username}!",
  "@greeting": {
    "description": "A welcome message with the user's name",
    "placeholders": {
      "username": {
        "type": "String",
        "example": "John Doe",
        "description": "The user's display name"
      }
    }
  }
}
```

### Exporting ARB Files `gen_l10n_utils export`

```bash
# Export to the default format (xlf or as specified in config)
dart run gen_l10n_utils export

# Export to a specific format
dart run gen_l10n_utils export --target xlf

# Export specific languages
dart run gen_l10n_utils export --language en,fr,de
```

This command:
- Uses the metadata version of ARB files for export
- Converts ARB files to the specified format (default is XLIFF/xlf)
- Preserves all metadata including descriptions and placeholders
- Creates target files in `lib/l10n/<format>/` directory
- Can export all languages or specific languages
- Will generate ARB files if they don't exist (after confirmation)

Example XLIFF output (`lib/l10n/xlf/app_de.xlf`):
```xml
<?xml version="1.0" encoding="UTF-8"?>
<xliff version="1.2" xmlns="urn:oasis:names:tc:xliff:document:1.2">
  <file source-language="en" target-language="de" datatype="plaintext" original="messages">
    <header>
      <tool tool-id="gen_l10n_utils" tool-name="gen_l10n_utils"/>
    </header>
    <body>
      <trans-unit id="greeting">
        <source>Welcome, {username}!</source>
        <target>Willkommen, {username}!</target>
        <note priority="1">A welcome message with the user's name</note>
        <note from="placeholder" name="username">Type: String, Example: John Doe, Description: The user's display name</note>
      </trans-unit>
    </body>
  </file>
</xliff>
```

Options:
- `--target` or `-t`: Output format (currently supported: `xlf`)
- `--language` or `-l`: Specific language(s) to export (comma-separated)

Currently supported export formats:
- `xlf`: XLIFF 1.2 format for translation tools with full metadata preservation

## Directory Structure Requirements

This package works with any common Flutter project structure, as long as your translation files follow these rules:

- All `.arb` files must be within the `/lib` folder
- Files must be placed in language-specific directories matching the ISO language codes from your config
- The directory path must include the language code (e.g., `/en/`, `/de/`, etc.)

Examples of supported structures:
- `lib/features/feature1/l10n/en/translations.arb`
- `lib/core/l10n/en/common.arb`
- `lib/modules/auth/assets/en/auth_strings.arb`
- `lib/en/app_translations.arb`

The tool will:
1. Find all `.arb` files under `/lib`
2. Determine the language by checking directory paths
3. Merge all files for each language
4. Generate two versions:
    - Simple translations (`app_[lang].arb`) -> Used by flutter_localizations
    - Full metadata version (`metadata/app_[lang]_metadata.arb`) -> Used for export
5. Place generated files in the `lib/l10n` directory

## Configuration

The `gen_l10n_utils.yaml` configuration file supports the following options:

| Option | Type | Description | Default |
|--------|------|-------------|---------|
| `base_language` | String | Base language to use as source for translations | `en` |
| `languages` | List\<String\> | List of supported language codes | `['en']` |
| `export_format` | String | Default format for exporting translations | `xlf` |

### Configuration File Example

```yaml
# Base language used as the source for translations
base_language: en

# All supported languages in your project
languages:
  - en
  - de
  - fr
  - es
  - ja

# Default format for exporting translations
export_format: xlf
```

## Integration with Flutter Localization

The generated simplified ARB files are compatible with Flutter's [flutter_localizations](https://api.flutter.dev/flutter/flutter_localizations-library.html) package and the [gen_l10n](https://pub.dev/packages/intl_translation) tool.

After generating your ARB files, you can use them with Flutter's localization system by configuring your `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter

flutter:
  generate: true
  uses-material-design: true

flutter_intl:
  enabled: true
  arb_dir: lib/l10n
  output_dir: lib/generated
```

## License

BSD 3-Clause License - see the [LICENSE](LICENSE) file for details.
