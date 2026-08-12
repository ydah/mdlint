# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

## 0.2.0 - Unreleased

### Added

- Added `lint`, `fix`, and `lsp` CLI commands while keeping formatting as the default command.
- Added lint fixes with `--fix`, `--fix-only`, and `--dry-run`.
- Added inline directives for disabling and enabling rules, including file-level and next-line controls.
- Added rule discovery and guidance through `--list-rules` and `--explain`, with Markdownlint-compatible rule IDs and aliases.
- Added configurable severities, fail levels, and text, JSON, SARIF, GitHub, Checkstyle, JUnit, and reviewdog output formats.
- Added YAML, TOML, and JSON front matter preservation during parsing and formatting.
- Added GFM tables, task lists, strikethrough, bare URL autolinks, and selectable Markdown dialects.
- Added HTML rendering through `Mdlint.html`.
- Added `--auto-gen-config`, parallel file processing, and content/configuration-hash caching.
- Added GitHub Action, reviewdog integration, and a pre-commit hook.
- Added LSP diagnostics, formatting, and quick fixes.
- Added the Japanese technical-writing preset (`JA001`–`JA007`), CJK-aware wrapping, link and anchor checks, and table-of-contents updates.
- Added optional fenced-code validation and formatting commands with configurable timeouts.
- Added 29 built-in lint rules and a stable plugin API for custom rules and dialect feature sets.

### Changed

- `Mdlint.lint` now honors rule selections, disabled rules, aliases, severity settings, and configuration-file options from `.mdlint.yml`.
- `Mdlint.fix` and rule fixes now consistently return formatted source strings.
- Markdown parsing and HTML rendering now handle nested lists, loose list items, reference links and images, entities, code spans, block quotes, directives, and common URI autolinks more consistently.
- GFM behavior is enabled explicitly with `dialect: :gfm` or `--dialect gfm`; CommonMark remains the default dialect.

### Fixed

- Fixed front matter being interpreted as thematic breaks, headings, or ordinary Markdown content.
- Fixed configured rules and disabled rules being ignored by the linter.
- Fixed inline links, reference links, images, escaped destinations, and nested link destinations being parsed or rendered incorrectly.
- Fixed formatter output changing document meaning in supported Markdown cases and added idempotence and HTML meaning-preservation checks.

## 0.1.0 - 2025-01-23

- Initial release
