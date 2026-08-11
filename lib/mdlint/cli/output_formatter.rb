# frozen_string_literal: true

require "json"

module Mdlint
  class CLI
    class OutputFormatter
      LEVELS = { error: "error", warning: "warning", info: "note" }.freeze

      def initialize(format)
        @format = format.to_s.downcase
      end

      def render(entries)
        return "" if entries.empty? && @format == "text"

        case @format
        when "json"
          json(entries)
        when "sarif"
          sarif(entries)
        when "github"
          github(entries)
        when "checkstyle"
          checkstyle(entries)
        when "junit"
          junit(entries)
        when "reviewdog", "rdjson"
          reviewdog(entries)
        else
          text(entries)
        end
      end

      private

      def text(entries)
        entries.map { |entry| "#{entry[:filename]}:#{entry[:violation]}" }.join("\n") + "\n"
      end

      def json(entries)
        JSON.generate(entries.map do |entry|
          entry[:violation].to_h.merge(file: entry[:filename])
        end) + "\n"
      end

      def github(entries)
        entries.map do |entry|
          violation = entry[:violation]
          command = violation.error? ? "error" : violation.info? ? "notice" : "warning"
          location = "file=#{entry[:filename]},line=#{violation.line}"
          location += ",col=#{violation.column}" if violation.column
          "::#{command} #{location}::[#{violation.rule_id}] #{violation.message}"
        end.join("\n") + "\n"
      end

      def sarif(entries)
        rules = entries.map { |entry| entry[:violation].rule_id }.uniq.filter_map do |rule_id|
          rule = Mdlint::Linter::RuleRegistry.find(rule_id)
          next unless rule

          {
            id: rule.rule_id,
            shortDescription: { text: rule.description.to_s }
          }
        end
        rule_indexes = rules.each_with_index.to_h { |rule, index| [rule[:id], index] }

        document = {
          version: "2.1.0",
          "$schema": "https://json.schemastore.org/sarif-2.1.0.json",
          runs: [{
            tool: { driver: { name: "mdlint", rules: rules } },
            results: entries.map do |entry|
              violation = entry[:violation]
              location = {
                physicalLocation: {
                  artifactLocation: { uri: entry[:filename] },
                  region: { startLine: violation.line }
                }
              }
              location[:physicalLocation][:region][:startColumn] = violation.column if violation.column
              {
                ruleId: violation.rule_id,
                ruleIndex: rule_indexes[violation.rule_id],
                level: LEVELS.fetch(violation.severity, "warning"),
                message: { text: violation.message },
                locations: [location]
              }
            end
          }]
        }
        JSON.generate(document) + "\n"
      end

      def checkstyle(entries)
        files = entries.group_by { |entry| entry[:filename] }.map do |filename, file_entries|
          errors = file_entries.map do |entry|
            violation = entry[:violation]
            attributes = {
              line: violation.line,
              column: violation.column,
              severity: violation.severity,
              message: "[#{violation.rule_id}] #{violation.message}",
              source: violation.rule_id
            }.compact.map { |key, value| "#{key}=\"#{xml_escape(value)}\"" }.join(" ")
            "    <error #{attributes}/>"
          end
          "  <file name=\"#{xml_escape(filename)}\">\n#{errors.join("\n")}\n  </file>"
        end
        "<checkstyle version=\"1.0\">\n#{files.join("\n")}\n</checkstyle>\n"
      end

      def junit(entries)
        cases = entries.map do |entry|
          violation = entry[:violation]
          name = "#{entry[:filename]}:#{violation.line}:#{violation.rule_id}"
          "    <testcase name=\"#{xml_escape(name)}\"><failure message=\"#{xml_escape(violation.message)}\"/></testcase>"
        end
        "<testsuite name=\"mdlint\" tests=\"#{entries.length}\" failures=\"#{entries.length}\">\n#{cases.join("\n")}\n</testsuite>\n"
      end

      def reviewdog(entries)
        document = {
          source: { name: "mdlint" },
          diagnostics: entries.map do |entry|
            violation = entry[:violation]
            column = violation.column || 1
            {
              message: "[#{violation.rule_id}] #{violation.message}",
              location: {
                path: entry[:filename],
                range: {
                  start: { line: violation.line, column: column },
                  end: { line: violation.line, column: column + 1 }
                }
              },
              severity: violation.severity.to_s.upcase
            }
          end
        }
        JSON.generate(document) + "\n"
      end

      def xml_escape(value)
        value.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;").gsub('"', "&quot;").gsub("'", "&apos;")
      end
    end
  end
end
