<h1 align="center">mdlint</h1>

<p align="center">
  <img src="https://img.shields.io/badge/ruby-%3E%3D%203.2-ruby.svg" alt="Ruby Version"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License"><a href="https://github.com/ydah/mdlint/actions/workflows/main.yml"><img src="https://github.com/ydah/mdlint/actions/workflows/main.yml/badge.svg?branch=main" alt="CI"></a><a href="https://badge.fury.io/rb/mdlint"><img src="https://badge.fury.io/rb/mdlint.svg" alt="Gem Version"></a>
</p>

<p align="center">
  A pure Ruby Markdown linter and formatter with zero external dependencies
</p>

<p align="center">
  <a href="#features">Features</a> •
  <a href="#quickstart">Quickstart</a> •
  <a href="#installation">Installation</a> •
  <a href="#usage">Usage</a> •
  <a href="#configuration">Configuration</a> •
  <a href="#lint-rules">Lint Rules</a> •
  <a href="#formatting-style">Formatting</a>
</p>

## Features

- Pure Ruby, no C/Rust extensions or external dependencies
- Linting with configurable rules and clear violations
- Auto-formatting that follows mdformat conventions
- CLI for CI-friendly workflows and local formatting
- Simple YAML configuration file

## Quickstart

```bash
gem install mdlint

# format in place
mdlint README.md docs/

# check-only (CI)
mdlint --check README.md

# show diffs
mdlint --diff README.md
```

## Installation

With Bundler:

```bash
bundle add mdlint
```

Without Bundler:

```bash
gem install mdlint
```

## Usage

Command line:

```bash
mdlint README.md docs/
mdlint --check README.md
mdlint --diff README.md
```

Options:

```
Usage: mdlint [options] [paths...]

Options:
    -c, --check              Check if files are formatted, exit with error if not
    -d, --diff               Show diff of changes
    -q, --quiet              Suppress output
    -e, --exclude PATTERN    Exclude files matching pattern
    -w, --wrap MODE          Paragraph wrapping: keep (default), no, or INTEGER
        --number             Use consecutive numbering for ordered lists
        --end-of-line MODE   End of line: lf (default), crlf, keep
    -v, --version            Show version
    -h, --help               Show help
```

Ruby API:

```ruby
require "mdlint"

formatted = Mdlint.format("# Hello World")
Mdlint.format_file("README.md")

tokens = Mdlint.parse("# Hello World")

violations = Mdlint.lint("# Heading\n\n\n\nParagraph")
violations.each { |v| puts v }

violations = Mdlint.lint_file("README.md")
```

## Configuration

Create a `.mdlint.yml` file in your project root:

```yaml
# Check mode (don't modify files)
check: false

# Quiet mode (suppress output)
quiet: false

# Exclude patterns
exclude:
  - "vendor/**/*.md"
  - "node_modules/**/*.md"
```

## Lint Rules

Key rules:

- Heading levels should increment by one
- Heading style should be consistent (ATX)
- No trailing spaces
- No multiple consecutive blank lines
- First line should be a top-level heading

## Formatting Style

| Element | Style |
|---------|-------|
| Headings | ATX style only (`#`) |
| Bullet lists | Hyphen (`-`), alternating for nested |
| Ordered lists | All items use `1.` (minimizes diffs) |
| Code blocks | Fenced style (`` ``` ``) |
| Horizontal rules | 70 underscores |
| Hard breaks | Backslash (`\`) |
| Line endings | LF (configurable) |
| Reference links | Converted to inline links |

## Supported Markdown Elements

Block elements:

- ATX headings (`# Heading`)
- Setext headings (converted to ATX)
- Paragraphs
- Bullet lists (`-`, `*`, `+`)
- Ordered lists (`1.`, `2.`)
- Blockquotes (`>`)
- Fenced code blocks (`` ``` ``)
- Indented code blocks (converted to fenced)
- Horizontal rules (`---`, `***`, `___`)
- HTML blocks
- Reference definitions

Inline elements:

- Bold (`**text**`, `__text__`)
- Italic (`*text*`, `_text_`)
- Inline code (`` `code` ``)
- Links (`[text](url)`)
- Reference links (`[text][ref]`)
- Images (`![alt](src)`)
- Autolinks (`<https://example.com>`)
- Hard breaks (backslash + newline)

## Development

```bash
bin/setup
bundle exec rspec
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/ydah/mdlint.

## License

MIT License. See `LICENSE.txt` for details.
