# frozen_string_literal: true

module Legion
  module Extensions
    module Curiosity
      module Helpers
        # Analyzes tick phase results for knowledge gaps that drive curiosity.
        module GapDetector
          module_function

          def detect(prior_results)
            detectors = %i[memory_retrieval prediction_engine emotional_evaluation contradiction_resolution]
            methods   = %i[detect_memory_gaps detect_prediction_gaps detect_emotional_gaps detect_contradiction_gaps]

            gaps = detectors.zip(methods).flat_map { |key, method| send(method, prior_results[key]) }

            gaps
              .select { |g| g[:information_gain] >= Constants::INFORMATION_GAIN_THRESHOLD }
              .sort_by { |g| -((g[:salience] * 0.6) + (g[:information_gain] * 0.4)) }
          end

          def detect_memory_gaps(result)
            return [] unless result.is_a?(Hash)

            gaps = []
            traces = result[:traces]
            domain = result[:domain] || :general

            gaps << unknown_domain_gap(traces, domain) if sparse_traces?(traces)
            gaps << incomplete_knowledge_gap(traces, domain) if weak_traces?(traces)
            gaps.compact
          end

          def detect_prediction_gaps(result)
            return [] unless result.is_a?(Hash)

            gaps = []
            gaps << low_confidence_gap(result) if low_confidence?(result)
            gaps << failed_prediction_gap(result) if failed_prediction?(result)
            gaps
          end

          def detect_emotional_gaps(result)
            return [] unless result.is_a?(Hash)

            valence = result[:valence]
            return [] unless valence.is_a?(Hash) && novel_unfamiliar?(valence)

            [novel_unfamiliar_gap(result, valence)]
          end

          def detect_contradiction_gaps(result)
            return [] unless result.is_a?(Hash)

            conflicts = result[:active_conflicts] || result[:conflicts]
            return [] unless conflicts.is_a?(Array) && !conflicts.empty?

            conflicts.first(3).map { |c| contradiction_gap(c) }
          end

          # -- private helpers below --

          def sparse_traces?(traces)
            traces.is_a?(Array) && traces.size < Constants::EMPTY_RETRIEVAL_THRESHOLD
          end

          def weak_traces?(traces)
            return false unless traces.is_a?(Array)

            traces.any? { |t| t.is_a?(Hash) && (t[:strength] || 1.0) < 0.3 }
          end

          def low_confidence?(result)
            c = result[:confidence]
            c.is_a?(Numeric) && c < Constants::LOW_CONFIDENCE_THRESHOLD
          end

          def failed_prediction?(result)
            result[:status] == :failed || result[:error]
          end

          def novel_unfamiliar?(valence)
            (valence[:novelty] || 0.0) > Constants::DIVERSIVE_NOVELTY_THRESHOLD &&
              (valence[:familiarity] || 1.0) < 0.3
          end

          def unknown_domain_gap(traces, domain)
            {
              gap_type:         :unknown,
              domain:           domain,
              question:         "What do I know about #{domain}?",
              salience:         0.6,
              information_gain: 0.7,
              source_trace_ids: traces&.filter_map { |t| t[:trace_id] } || []
            }
          end

          def incomplete_knowledge_gap(traces, domain)
            weak = traces.select { |t| t.is_a?(Hash) && (t[:strength] || 1.0) < 0.3 }
            return nil if weak.empty?

            {
              gap_type:         :incomplete,
              domain:           domain,
              question:         'Why are my memories about this topic weak?',
              salience:         0.4,
              information_gain: 0.5,
              source_trace_ids: weak.filter_map { |t| t[:trace_id] }
            }
          end

          def low_confidence_gap(result)
            confidence = result[:confidence]
            {
              gap_type:         :uncertain,
              domain:           result[:domain] || :general,
              question:         "Why is my prediction confidence low (#{(confidence * 100).round}%)?",
              salience:         0.7,
              information_gain: 0.6,
              source_trace_ids: []
            }
          end

          def failed_prediction_gap(result)
            {
              gap_type:         :uncertain,
              domain:           result[:domain] || :general,
              question:         'What caused this prediction failure?',
              salience:         0.8,
              information_gain: 0.7,
              source_trace_ids: []
            }
          end

          def novel_unfamiliar_gap(result, valence)
            novelty = valence[:novelty] || 0.0
            familiarity = valence[:familiarity] || 1.0
            {
              gap_type:         :unknown,
              domain:           result[:domain] || :general,
              question:         'This is novel and unfamiliar — what is it?',
              salience:         novelty,
              information_gain: (1.0 - familiarity) * 0.8,
              source_trace_ids: []
            }
          end

          def contradiction_gap(conflict)
            domain = conflict.is_a?(Hash) ? (conflict[:domain] || :general) : :general
            {
              gap_type:         :contradictory,
              domain:           domain,
              question:         "Why do I have contradictory knowledge about #{domain}?",
              salience:         0.8,
              information_gain: 0.7,
              source_trace_ids: conflict.is_a?(Hash) ? Array(conflict[:trace_ids]) : []
            }
          end
        end
      end
    end
  end
end
