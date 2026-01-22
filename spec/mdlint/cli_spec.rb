# frozen_string_literal: true

require "mdlint/cli"
require "tempfile"

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
end
