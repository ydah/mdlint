# frozen_string_literal: true

require "thread"

module Mdlint
  class ParallelRunner
    class << self
      def map(items, jobs: 1)
        return items.map { |item| yield item } unless jobs.to_i > 1 && items.length > 1

        queue = Queue.new
        items.each_with_index { |item, index| queue << [index, item] }
        results = Array.new(items.length)
        errors = Queue.new
        workers = Array.new([jobs.to_i, items.length].min) do
          Thread.new do
            Thread.current.report_on_exception = false
            process_queue(queue, results, errors) { |item| yield item }
          end
        end
        workers.each(&:join)
        raise errors.pop unless errors.empty?

        results
      end

      private

      def process_queue(queue, results, errors)
        loop do
          index, item = queue.pop(true)
          results[index] = yield item
        rescue ThreadError
          break
        rescue StandardError => error
          errors << error
          break
        end
      end
    end
  end
end
