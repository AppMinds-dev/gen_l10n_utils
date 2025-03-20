# gen_l10n_utils

A powerful toolkit for Flutter localization that extends the functionality of the standard ARB file generation process. It manages the extraction, merging, and exporting of localization files across your project.

## Features

- **Automatic ARB File Generation**: Finds and merges all translations in your project
- **Metadata Preservation**: Keeps descriptions and placeholder details
- **Multiple Export Formats**:
  - `csv`: CSV format with key, source, target, description and placeholder details
  - `json`: Simplified JSON format with metadata structured for easy processing
  - `po`: Gettext PO format with comments for metadata preservation
  - `xlf`: XLIFF format for CAT (Computer-Assisted Translation) tool compatibility
  - `xlsx`: Excel format with separate sheets for translations and metadata
  - `yaml`: YAML format with structured metadata for easy reading and editing

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

## Usage

### CLI Commands

```bash
# Generate ARB files
gen_l10n_utils generate

# Export translations
gen_l10n_utils export --format xlf
gen_l10n_utils export --format json
gen_l10n_utils export --format po
gen_l10n_utils export --format yaml
gen_l10n_utils export --format xlsx
gen_l10n_utils export --format csv
```

### Export Formats

#### XLIFF (xlf)
Standard XML format for translation tools. Includes source text, translations, and metadata.

#### JSON (json)
Simplified JSON format with structured metadata. Easy to process programmatically.

#### Gettext PO (po)
Industry-standard format with full support for translator comments and context.

#### YAML (yaml)
Human-readable format with structured metadata. Good for manual editing.

#### Excel (xlsx)
Spreadsheet format with three sheets:
- Overview: Project information
- Translations: Source and target text
- Metadata: Descriptions and placeholder details

#### CSV (csv)
Comma-separated values format with columns for:
- Key: Translation identifier
- Source: Text in base language
- Target: Text in target language
- Description: Context and usage notes
- Placeholder: Variable name
- Placeholder Details: Type, example, and description

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