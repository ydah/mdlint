# frozen_string_literal: true

require "mdlint/config"
require "tempfile"
require "fileutils"

RSpec.describe Mdlint::Config do
  let(:tmpdir) { Dir.mktmpdir }

  after { FileUtils.remove_entry(tmpdir) }

  describe "#load" do
    it "returns default options when no config file exists" do
      config = described_class.new(tmpdir)
      options = config.load

      expect(options[:check]).to be false
      expect(options[:diff]).to be false
      expect(options[:quiet]).to be false
      expect(options[:exclude]).to eq([])
    end

    it "loads options from .mdlint.yml" do
      File.write(File.join(tmpdir, ".mdlint.yml"), <<~YAML)
        check: true
        exclude:
          - "vendor/**/*.md"
          - "node_modules/**/*.md"
      YAML

      config = described_class.new(tmpdir)
      options = config.load

      expect(options[:check]).to be true
      expect(options[:exclude]).to eq(["vendor/**/*.md", "node_modules/**/*.md"])
    end

    it "finds config in parent directories" do
      subdir = File.join(tmpdir, "sub", "dir")
      FileUtils.mkdir_p(subdir)
      File.write(File.join(tmpdir, ".mdlint.yml"), "quiet: true\n")

      config = described_class.new(subdir)
      options = config.load

      expect(options[:quiet]).to be true
    end
  end

  describe "#merge" do
    it "merges CLI options with config options" do
      File.write(File.join(tmpdir, ".mdlint.yml"), <<~YAML)
        exclude:
          - "vendor/**/*.md"
      YAML

      config = described_class.new(tmpdir)
      config.load
      options = config.merge(check: true, exclude: ["test/**/*.md"])

      expect(options[:check]).to be true
      expect(options[:exclude]).to contain_exactly("vendor/**/*.md", "test/**/*.md")
    end

    it "CLI options override config file options" do
      File.write(File.join(tmpdir, ".mdlint.yml"), "check: false\n")

      config = described_class.new(tmpdir)
      config.load
      options = config.merge(check: true)

      expect(options[:check]).to be true
    end
  end
end
