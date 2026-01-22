# Mdlint

A Pure Ruby Markdown linter and formatter. No external dependencies required.

## Features

- **Pure Ruby** - No C extensions, Rust extensions, or external dependencies
- **Linting** - Detect common Markdown issues with configurable rules
- **Formatting** - Automatically format Markdown files for consistency
- **CLI** - Command-line interface for easy integration into workflows
- **Configuration** - YAML configuration file support

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'mdlint'
```

And then execute:

```bash
bundle install
```

Or install it yourself as:

```bash
gem install mdlint
```

## Usage

### Command Line

Format Markdown files in place:

```bash
mdlint README.md docs/
```

Check if files are formatted (useful for CI):

```bash
mdlint --check README.md
```

Show diff of changes:

```bash
mdlint --diff README.md
```

### Options

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

### Ruby API

```ruby
require 'mdlint'

# Format a string
formatted = Mdlint.format("# Hello World")

# Format a file
Mdlint.format_file("README.md")

# Parse to tokens
tokens = Mdlint.parse("# Hello World")

# Lint a string
violations = Mdlint.lint("# Heading\n\n\n\nParagraph")
violations.each { |v| puts v }

# Lint a file
violations = Mdlint.lint_file("README.md")
```

### Configuration

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

| Rules |
|-------------|
| Heading levels should increment by one |
| Heading style should be consistent (ATX) |
| No trailing spaces |
| No multiple consecutive blank lines |
| First line should be a top-level heading |

## Formatting Style (mdformat compatible)

mdlint follows the [mdformat](https://github.com/hukkin/mdformat) style:

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

### Block Elements

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

### Inline Elements

- Bold (`**text**`, `__text__`)
- Italic (`*text*`, `_text_`)
- Inline code (`` `code` ``)
- Links (`[text](url)`)
- Reference links (`[text][ref]`)
- Images (`![alt](src)`)
- Autolinks (`<https://example.com>`)
- Hard breaks (backslash + newline)

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests.

```bash
bundle install
bundle exec rspec
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/ydah/mdlint.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
