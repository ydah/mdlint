# frozen_string_literal: true

module Mdlint
  module Plugin
    class Error < Mdlint::Error
    end

    def self.register_rule(rule_class)
      unless defined?(Mdlint::Linter::Rule) && rule_class.is_a?(Class) && rule_class < Mdlint::Linter::Rule
        raise Error, "plugin rules must inherit from Mdlint::Linter::Rule"
      end

      Mdlint::Linter::RuleRegistry.register(rule_class)
      rule_class
    end

    def self.register_dialect(name, features: [])
      Mdlint::Dialect.register(name, features: features)
    end

    def self.load(path)
      require File.expand_path(path, Dir.pwd)
    rescue LoadError, StandardError => error
      raise Error, "could not load plugin #{path}: #{error.message}"
    end
  end
end
