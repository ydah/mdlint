# frozen_string_literal: true

module Mdlint
  module Linter
    module Rules
      module JapaneseHelpers
        CJK = /[\p{Han}\p{Hiragana}\p{Katakana}\p{Hangul}]/
        JAPANESE = /[\p{Han}\p{Hiragana}\p{Katakana}]/

        private

        def each_inline(tokens)
          tokens.each do |token|
            yield token if token.type == :inline
          end
        end

        def prose_content(token)
          token.children.filter_map do |child|
            child.content if %i[text html_inline softbreak hardbreak].include?(child.type)
          end.join
        end

        def line_for(token)
          (token.map&.first || 0) + 1
        end
      end

      class JapaneseSpacing < Rule
        include JapaneseHelpers

        self.rule_id = "JA001"
        self.aliases = ["japanese-spacing"]
        self.description = "Japanese and ASCII text should use consistent spacing"
        self.preset = :japanese

        def check(tokens, _source)
          each_inline(tokens) do |token|
            content = prose_content(token)
            next unless content.match?(JAPANESE)
            next unless content.match?(/(?:#{JAPANESE})[A-Za-z0-9]|[A-Za-z0-9](?:#{JAPANESE})/)

            add_violation(
              message: "Add a space between Japanese and ASCII text",
              line: line_for(token),
              fixable: false
            )
          end
          @violations
        end
      end

      class JapanesePunctuation < Rule
        include JapaneseHelpers

        self.rule_id = "JA002"
        self.aliases = ["japanese-punctuation"]
        self.description = "Japanese prose should use full-width punctuation"
        self.preset = :japanese

        def check(tokens, _source)
          each_inline(tokens) do |token|
            content = prose_content(token)
            next unless content.match?(JAPANESE)
            next unless content.match?(/[、。！？] |[,:!?](?:#{JAPANESE})|(?<!\.)\.(?:#{JAPANESE})/)

            add_violation(
              message: "Use Japanese punctuation consistently in Japanese prose",
              line: line_for(token),
              fixable: false
            )
          end
          @violations
        end
      end

      class JapaneseStyle < Rule
        include JapaneseHelpers

        self.rule_id = "JA003"
        self.aliases = ["japanese-style"]
        self.description = "Japanese documents should not mix desu-masu and de-aru styles"
        self.preset = :japanese

        def check(tokens, _source)
          prose = tokens.filter_map { |token| prose_content(token) if token.type == :inline }.join("\n")
          has_desu_masu = prose.match?(/です(?:。|\z)|ます(?:。|\z)|でした(?:。|\z)|ません(?:。|\z)/)
          has_de_aru = prose.match?(/である(?:。|\z)|だ(?:。|\z)|であった(?:。|\z)/)
          return @violations unless has_desu_masu && has_de_aru

          token = tokens.find { |candidate| candidate.type == :inline }
          add_violation(
            message: "Avoid mixing desu-masu and de-aru styles",
            line: line_for(token),
            fixable: false
          )
          @violations
        end
      end

      class JapaneseSentenceLength < Rule
        include JapaneseHelpers

        self.rule_id = "JA004"
        self.aliases = ["japanese-sentence-length"]
        self.description = "Japanese sentences should stay within the configured length"
        self.preset = :japanese

        def check(tokens, _source)
          maximum = @options.fetch(:sentence_length, 80).to_i
          return @violations if maximum <= 0

          each_inline(tokens) do |token|
            prose_content(token).split(/(?<=[。！？!?])\s*/).each do |sentence|
              next if sentence.empty? || sentence.each_char.count <= maximum

              add_violation(
                message: "Sentence length #{sentence.each_char.count} exceeds #{maximum}",
                line: line_for(token),
                fixable: false
              )
            end
          end
          @violations
        end
      end

      class JapaneseCommaCount < Rule
        include JapaneseHelpers

        self.rule_id = "JA005"
        self.aliases = ["japanese-comma-count"]
        self.description = "Japanese sentences should not contain too many commas"
        self.preset = :japanese

        def check(tokens, _source)
          maximum = @options.fetch(:max_commas, 3).to_i
          each_inline(tokens) do |token|
            prose_content(token).split(/(?<=[。！？!?])\s*/).each do |sentence|
              commas = sentence.count("、,")
              next unless commas > maximum

              add_violation(
                message: "Sentence contains #{commas} commas (maximum #{maximum})",
                line: line_for(token),
                fixable: false
              )
            end
          end
          @violations
        end
      end

      class JapaneseDuplicateParticle < Rule
        include JapaneseHelpers

        self.rule_id = "JA006"
        self.aliases = ["japanese-duplicate-particle"]
        self.description = "Avoid repeated Japanese particles in a short phrase"
        self.preset = :japanese

        def check(tokens, _source)
          each_inline(tokens) do |token|
            next unless prose_content(token).match?(/の[^。！？\n]{0,12}の|に[^。！？\n]{0,12}に/)

            add_violation(
              message: "Check repeated Japanese particles such as の or に",
              line: line_for(token),
              fixable: false
            )
          end
          @violations
        end
      end

      class JapaneseWidth < Rule
        include JapaneseHelpers

        self.rule_id = "JA007"
        self.aliases = ["japanese-width"]
        self.description = "Japanese prose should use full-width brackets and punctuation"
        self.preset = :japanese

        def check(tokens, _source)
          each_inline(tokens) do |token|
            content = prose_content(token)
            next unless content.match?(JAPANESE)
            next unless content.match?(/[()\[\]{},.!?;:]/)

            add_violation(
              message: "Use full-width brackets and punctuation in Japanese prose",
              line: line_for(token),
              fixable: false
            )
          end
          @violations
        end
      end
    end
  end
end
