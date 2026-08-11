# frozen_string_literal: true

require "mdlint/cli"
require "tempfile"
require "stringio"

RSpec.describe Mdlint::CLI do
  describe "--help" do
    it "shows help message" do
      expect { described_class.new(["--help"]).run }.to output(/Usage: mdlint/).to_stdout.and raise_error(SystemExit)
    end
  end

  describe "--version" do
    it "shows version" do
      expect { described_class.new(["--version"]).run }.to output(/mdlint #{Mdlint::VERSION}/).to_stdout.and raise_error(SystemExit)
    end
  end

  describe "file processing" do
    let(:tempfile) do
      file = Tempfile.new(["test", ".md"])
      file.write("#  Heading\n")
      file.flush
      file
    end

    after { tempfile.close! }

    it "formats a file in place" do
      cli = described_class.new([tempfile.path])
      cli.run

      expect(File.read(tempfile.path).rstrip).to eq("# Heading")
    end

    it "checks formatting with --check" do
      cli = described_class.new(["--check", tempfile.path])
      expect { cli.run }.to raise_error(SystemExit) do |error|
        expect(error.status).to eq(1)
      end
    end
  end

  describe "stdin processing" do
    it "formats stdin when no paths are provided" do
      original_stdin = $stdin
      $stdin = StringIO.new("#  Heading\n")

      expect { described_class.new([]).run }.to output("# Heading\n\n").to_stdout
    ensure
      $stdin = original_stdin
    end

    it "exits with non-zero on --check when stdin differs" do
      original_stdin = $stdin
      $stdin = StringIO.new("#  Heading\n")

      expect { described_class.new(["--check"]).run }.to raise_error(SystemExit) do |error|
        expect(error.status).to eq(1)
      end
    ensure
      $stdin = original_stdin
    end
  end

  describe "options" do
    it "respects --exclude patterns" do
      Dir.mktmpdir do |dir|
        included = File.join(dir, "included.md")
        excluded = File.join(dir, "excluded.md")
        File.write(included, "#  Title\n")
        File.write(excluded, "#  Excluded\n")

        cli = described_class.new(["--exclude", "**/excluded.md", dir])
        cli.run

        expect(File.read(included).rstrip).to eq("# Title")
        expect(File.read(excluded).rstrip).to eq("#  Excluded")
      end
    end

    it "warns about missing paths" do
      expect { described_class.new(["missing.md"]).run }.to output(/does not exist/).to_stderr
    end

    it "warns and falls back on invalid wrap mode" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "file.md")
        File.write(path, "Line\n")

        expect { described_class.new(["--wrap", "bad", path]).run }.to output(/Invalid wrap mode/).to_stderr
      end
    end

    it "runs lint as a subcommand" do
      original_stdin = $stdin
      $stdin = StringIO.new("# Heading\n\n### Jump\n")

      expect { described_class.new(["lint"]).run }.to output(/stdin:\[MD001\]/).to_stdout.and raise_error(SystemExit) do |error|
        expect(error.status).to eq(1)
      end
    ensure
      $stdin = original_stdin
    end

    it "honors fail level for lint diagnostics" do
      original_stdin = $stdin
      $stdin = StringIO.new("# Heading\n\n### Jump\n")

      expect { described_class.new(["lint", "--fail-level", "error"]).run }.to output(/MD001/).to_stdout
    ensure
      $stdin = original_stdin
    end

    it "lists and explains rules" do
      expect { described_class.new(["--list-rules"]).run }.to output(/MD001.*heading-increment/m).to_stdout.and raise_error(SystemExit)
      expect { described_class.new(["--explain", "heading-increment"]).run }.to output(/Heading levels/).to_stdout.and raise_error(SystemExit)
    end
  end
end
