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
- GitHub Action and RBS/Steep signatures for integration and tooling
- reviewdog-compatible RDJSON output through the CLI and GitHub Action
- Language Server Protocol diagnostics, formatting, and quick fixes
- Parallel linting with a content/configuration-hash cache
- Japanese technical-writing preset, code-block syntax checks, link/anchor checks, and TOC updates
- Optional language commands for code-block validation and formatting
- 29 built-in lint rules with Markdownlint-compatible IDs and aliases
- Stable plugin registration for custom rules and dialect feature sets

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

Commands: format (default), lint, fix, lsp

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
        --format FORMAT       Lint output: text, json, sarif, github, checkstyle, junit, reviewdog
        --stdin-filename NAME Filename to use for stdin diagnostics
        --dialect DIALECT     Markdown dialect: commonmark or gfm
        --preset NAME          Enable a rule preset, such as japanese
        --check-links          Check relative link, image, and anchor targets
        --check-external-links Check external HTTP(S) links
        --check-code-blocks    Validate supported fenced code blocks
        --code-block-command SPEC Validate a language block with LANG=COMMAND
        --code-block-formatter SPEC Format a language block with LANG=COMMAND
        --code-block-timeout SECONDS Timeout for external code-block commands
        --toc                  Update table-of-contents markers
        --no-table-align       Do not pad GFM table columns
        --jobs N               Process files concurrently
        --cache                Cache lint diagnostics
        --cache-path PATH      Path for the lint cache
        --lsp                  Run the Language Server Protocol server
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
toc_updated = Mdlint.update_toc("# Hello\n\n<!-- toc -->\nold\n<!-- toc -->\n")
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

# Optional integrations
preset: japanese
toc: false
check_links: false
check_external_links: false
check_code_blocks: false
code_block_timeout: 10
jobs: 2
cache: true
cache_path: .mdlint_cache

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

# A plugin may register a feature subset for a project-specific dialect.
# Mdlint::Plugin.register_dialect(:docs, features: [:tables])
```

## Lint Rules

Key rules:

- Heading levels should increment by one
- Heading style should be consistent (ATX)
- No trailing spaces
- No multiple consecutive blank lines
- First line should be a top-level heading
- Lines should respect MD013's configured length
- Relative links, images, and anchors can be checked with `mdlint lint --check-links`.
- External HTTP(S) links are opt-in with `--check-external-links`.
- `--preset japanese` enables JA001–JA007 writing checks; options include `sentence_length` and `max_commas`.
- `--check-code-blocks` validates JSON and Ruby fenced blocks.
- `--code-block-command python='python -m py_compile -'` adds opt-in validation for another language; commands receive block content on stdin.
- `--code-block-formatter python='black -'` can rewrite an external language block; commands are bounded by `code_block_timeout` (10 seconds by default).
- `--toc` regenerates content between paired `<!-- toc -->` or `<!-- toc:start -->` / `<!-- toc:end -->` markers.

Plugins can use the stable API from a required Ruby file:

```ruby
class MyRule < Mdlint::Linter::Rule
  self.rule_id = "PL001"
  self.aliases = ["my-rule"]
  self.description = "Project-specific Markdown rule"
end

Mdlint::Plugin.register_rule(MyRule)
Mdlint::Plugin.register_dialect(:docs, features: [:tables, :task_lists])
```

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
| Bullet lists | Hyphen (`-`) at every nesting level |
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
- Footnotes, fenced math blocks, GitHub alerts, and MDX/JSX component blocks

Inline elements:

- Bold (`**text**`, `__text__`)
- Italic (`*text*`, `_text_`)
- Inline code (`` `code` ``)
- Links (`[text](url)`)
- Reference links (`[text][ref]`)
- Images (`![alt](src)`)
- Autolinks (`<https://example.com>`)
- Hard breaks (backslash + newline)

With `dialect: gfm`, tables, task lists, strikethrough, and bare URL autolinks are supported. Footnote definitions/references, fenced math blocks, GitHub alerts, and MDX/JSX blocks are preserved and included in HTML output.

## Development

```bash
bin/setup
bundle exec rspec
rbs validate
steep check --no-daemon --severity-level error

# Optional quality tools
ruby script/fetch_commonmark_spec.rb
bundle exec rspec spec/commonmark_spec.rb
ITERATIONS=100 ruby benchmark/format.rb README.md
ruby script/commonmark_compatibility.rb spec/fixtures/commonmark_smoke.json
ITERATIONS=100 ruby benchmark/compare.rb README.md
# Property tests cover formatter idempotence and HTML meaning preservation.
bundle exec rspec spec/mdlint/property_spec.rb
bundle exec rake property
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/ydah/mdlint.

## License

MIT License. See `LICENSE.txt` for details.
