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
- YAML/TOML/JSON front matter preservation
- GFM tables, task lists, strikethrough, and configurable dialects
- Text, JSON, SARIF, Checkstyle, JUnit, and GitHub diagnostic output
- Optional HTML rendering through the Ruby API

## Quickstart

```bash
gem install mdlint

# format in place
mdlint README.md docs/

# check-only (CI)
mdlint --check README.md

# show diffs
mdlint --diff README.md

# lint and report violations
mdlint lint docs/

# fix fixable lint violations
mdlint fix --dry-run docs/
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
mdlint lint README.md
mdlint fix README.md
```

Options:

```
Usage: mdlint [command] [options] [paths...]

Commands: format (default), lint, fix

Options:
    -c, --check              Check if files are formatted, exit with error if not
    -d, --diff               Show diff of changes
    -q, --quiet              Suppress output
    -e, --exclude PATTERN    Exclude files matching pattern
    -w, --wrap MODE          Paragraph wrapping: keep (default), no, or INTEGER
        --number             Use consecutive numbering for ordered lists
    --end-of-line MODE   End of line: lf (default), crlf, keep
        --fix                 Fix fixable lint violations
        --fix-only            Apply fixes without reporting remaining violations
        --dry-run             Do not write fixes to files
        --disable RULES       Disable comma-separated rules
        --rule RULES          Run only comma-separated rules
        --severity LEVEL      Default severity: error, warning, or info
        --fail-level LEVEL    Fail at severity: error, warning, or info
        --format FORMAT       Lint output: text, json, sarif, github, checkstyle, junit
        --stdin-filename NAME Filename to use for stdin diagnostics
        --dialect DIALECT     Markdown dialect: commonmark or gfm
        --check-links          Check relative link and image targets
        --list-rules           List available lint rules
        --explain RULE        Explain a lint rule
        --require PATH        Load a custom rule file
        --auto-gen-config     Write a config disabling current violations
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

fixed = Mdlint.fix("Line  \n")
html = Mdlint.html("# Hello\n\n**world**\n")
gfm_tokens = Mdlint.parse("- [x] Done\n", dialect: :gfm)
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

# Markdown dialect
dialect: commonmark # or gfm

# Rule configuration (markdownlint-compatible IDs and aliases are accepted)
rules:
  MD013:
    enabled: true
    line_length: 120
    ignore_code_blocks: true
  MD009: false

# Severity and CI threshold
severity: warning
fail_level: error

# Custom rule files
plugins:
  - "./rules/my_rule.rb"
```

## Lint Rules

Key rules:

- Heading levels should increment by one
- Heading style should be consistent (ATX)
- No trailing spaces
- No multiple consecutive blank lines
- First line should be a top-level heading
- Lines should respect MD013's configured length
- Relative links can be checked with `mdlint lint --check-links` (external URLs are not requested).

Inline directives can suppress diagnostics for a section or one line:

```markdown
<!-- mdlint-disable MD013 -->
long content is allowed here
<!-- mdlint-enable MD013 -->
<!-- mdlint-disable-next-line MD001 -->
### Intentional jump
```

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

With `dialect: gfm`, tables, task lists, strikethrough, and bare URL autolinks are supported.
Footnote definitions/references and fenced math blocks are preserved and included in HTML output.

## Development

```bash
bin/setup
bundle exec rspec
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/ydah/mdlint.

## License

MIT License. See `LICENSE.txt` for details.
