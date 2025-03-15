# AppMinds Localization Tools

A command-line tool for managing Flutter application localization resources.

## Features

- **Configuration Management**: Create and update localization configuration files
- **ARB Generation**: Generate ARB (Application Resource Bundle) files for translations
- **Language Support**: Configure multiple languages with a default language
- **Simple CLI Interface**: Easy-to-use commands with helpful options
- **Nested JSON Support**: Merge nested JSON structures into flat dot notation

## Installation

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  appminds_l10n_tools: ^1.0.0
```

Or install it globally:

```bash
dart pub global activate appminds_l10n_tools
```

## Usage

> **Note:** A configuration file (`appminds_l10n.yaml` or `al10n.yaml`) is required at your project's root level.

### Creating a configuration file `al10n create-config`

```bash
dart run al10n create-config --default-language en --languages en,de,fr
# or
dart run al10n create-config -d en -l en,de,fr
```

This creates an `al10n.yaml` file in your project root with your specified languages:

```yaml
default_language: en
languages:
  - en
  - de
  - fr
```

Options:
- `--default-language` or `-d`: Default language code (ISO 639-1) [default: **en**]
- `--languages` or `-l`: Language codes to support (comma separated) [default: **en**]

### Generating ARB files `al10n gen-arb`

```bash
dart run al10n gen-arb
```

This command:
- Finds all .arb files in your project
- Detects languages based on directory paths
- Merges translations into combined ARB files (app_en.arb, etc.) in the `lib/l10n` directory

The command automatically:
- Identifies language by checking directory paths containing language codes
- Merges multiple ARB files for the same language
- Creates output files in the `lib/l10n` directory

I'll add information about running the Flutter/Dart localization generation command after using `al10n gen-arb`. Here's the addition to include in your README:

## Generating Flutter Localization Files

After running `al10n gen-arb` to create your merged ARB files, you need to run Flutter's localization code generation tool to create the Dart classes:

```bash
flutter gen-l10n
```

This command will process the ARB files in your `lib/l10n` directory and generate the necessary Dart code according to your Flutter project's configuration.

Alternatively, if you're using the `flutter_localizations` package with `generate: true` in your `pubspec.yaml`, this generation will happen automatically when you build or run your app.

For more information on Flutter's internationalization system, see the [official documentation](https://docs.flutter.dev/development/accessibility-and-localization/internationalization).

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
4. Generate combined output files named `app_[lang].arb` (e.g., `app_en.arb`, `app_de.arb`)
5. Place generated files in the `lib/l10n` directory

## Nested JSON Support

This tool allows you to use nested JSON structures in your translation files, which makes organization easier. When merging files, the tool will appropriately handle these structures and produce properly formatted ARB files compatible with Flutter's localization system.

For example, you can organize your translations like this:

```json
{
  "auth": {
    "login": "Login",
    "register": "Register",
    "forgotPassword": "Forgot Password"
  }
}
```

The tool will merge and maintain these nested structures in the final output files, enabling you to keep your translations organized by feature or section.

## Integration with Flutter Localization

The generated ARB files are compatible with Flutter's [flutter_localizations](https://api.flutter.dev/flutter/flutter_localizations/flutter_localizations-library.html) package and the [gen_l10n](https://pub.dev/packages/intl_translation) tool.

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

## Configuration

The package requires either `appminds_l10n.yaml` or `al10n.yaml` in your project root:

```yaml
default_language: en
languages:
  - en
  - de
  - fr
```

## License

BSD 3-Clause License - see the [LICENSE.md](LICENSE.md) file for details.
