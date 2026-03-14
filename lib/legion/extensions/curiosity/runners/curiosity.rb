# frozen_string_literal: true

module Legion
  module Extensions
    module Curiosity
      module Runners
        # Runner methods for the curiosity engine: gap detection, wonder lifecycle, agenda formation.
        module Curiosity
          include Legion::Extensions::Helpers::Lex if Legion::Extensions.const_defined?(:Helpers) &&
                                                      Legion::Extensions::Helpers.const_defined?(:Lex)

          def detect_gaps(prior_results: {}, **)
            gaps = Helpers::GapDetector.detect(prior_results)
            Legion::Logging.debug "[curiosity] detected #{gaps.size} knowledge gaps"

            created = create_wonders_from_gaps(gaps)
            build_detect_result(gaps, created)
          end

          def generate_wonder(question:, domain: :general, gap_type: :unknown,
                              salience: 0.5, information_gain: 0.5,
                              source_trace_ids: [], **)
            wonder = Helpers::Wonder.new_wonder(
              question: question, domain: domain, gap_type: gap_type,
              salience: salience, information_gain: information_gain,
              source_trace_ids: source_trace_ids
            )
            wonder_store.store(wonder)
            Legion::Logging.info "[curiosity] manually generated wonder: #{question}"
            wonder
          end

          def explore_wonder(wonder_id:, **)
            wonder = wonder_store.get(wonder_id)
            return { error: :not_found } unless wonder
            return { error: :already_resolved } if wonder[:resolved]
            return { error: :not_explorable, reason: :max_attempts } unless Helpers::Wonder.explorable?(wonder)

            wonder_store.update(wonder_id, attempts: wonder[:attempts] + 1, last_explored_at: Time.now.utc)
            Legion::Logging.info "[curiosity] exploring: #{wonder[:question]} (attempt ##{wonder[:attempts] + 1})"
            { exploring: true, wonder_id: wonder_id, attempt: wonder[:attempts] + 1 }
          end

          def resolve_wonder(wonder_id:, resolution:, actual_gain: 0.5, **)
            wonder = wonder_store.get(wonder_id)
            return { error: :not_found } unless wonder
            return { error: :already_resolved } if wonder[:resolved]

            resolved = wonder_store.mark_resolved(wonder_id, resolution: resolution, actual_gain: actual_gain)
            build_resolve_result(wonder, resolved, actual_gain)
          end

          def curiosity_intensity(**)
            intensity = compute_intensity
            Legion::Logging.debug "[curiosity] intensity=#{intensity.round(3)}"
            { intensity: intensity, active_wonders: wonder_store.active_count,
              resolution_rate: wonder_store.resolution_rate.round(3), top_domain: top_curiosity_domain }
          end

          def top_wonders(limit: 5, **)
            wonders = wonder_store.top_balanced(limit: limit)
            Legion::Logging.debug "[curiosity] top #{wonders.size} wonders requested"
            { wonders: wonders.map { |w| format_wonder(w) } }
          end

          def form_agenda(**)
            wonders = wonder_store.top_balanced(limit: 5)
            Legion::Logging.debug "[curiosity] forming agenda from #{wonders.size} wonders"
            { agenda_items: wonders.map { |w| format_agenda_item(w) }, source: :curiosity }
          end

          def wonder_stats(**)
            { total_generated: wonder_store.total_generated, active: wonder_store.active_count,
              resolved: wonder_store.resolved_count, resolution_rate: wonder_store.resolution_rate.round(3),
              intensity: compute_intensity.round(3), domains: wonder_store.domain_stats }
          end

          def decay_wonders(hours_elapsed: 1.0, **)
            pruned = wonder_store.decay_all(hours_elapsed: hours_elapsed)
            Legion::Logging.debug "[curiosity] decay: pruned=#{pruned} remaining=#{wonder_store.active_count}"
            { pruned: pruned, remaining: wonder_store.active_count }
          end

          private

          def wonder_store
            @wonder_store ||= Helpers::WonderStore.new
          end

          def create_wonders_from_gaps(gaps)
            gaps.each_with_object([]) do |gap, created|
              next if duplicate_wonder?(gap)

              wonder = Helpers::Wonder.new_wonder(**gap.slice(:question, :domain, :gap_type,
                                                              :salience, :information_gain, :source_trace_ids))
              wonder_store.store(wonder)
              created << wonder
              Legion::Logging.info "[curiosity] new wonder: #{wonder[:question]} (#{wonder[:gap_type]}/#{wonder[:domain]})"
            end
          end

          def build_detect_result(gaps, created)
            intensity = compute_intensity
            top = wonder_store.top_balanced(limit: 3)
            Legion::Logging.debug "[curiosity] intensity=#{intensity.round(3)} active=#{wonder_store.active_count}"
            { gaps_detected: gaps.size, wonders_created: created.size, curiosity_intensity: intensity,
              top_wonders: top.map { |w| { wonder_id: w[:wonder_id], question: w[:question], score: Helpers::Wonder.score(w).round(3) } },
              active_count: wonder_store.active_count }
          end

          def build_resolve_result(wonder, resolved, actual_gain)
            reward = actual_gain * Helpers::Constants::CURIOSITY_REWARD_MULTIPLIER
            Legion::Logging.info "[curiosity] resolved: #{wonder[:question]} gain=#{actual_gain.round(2)}"
            { resolved: true, wonder_id: wonder[:wonder_id], actual_gain: actual_gain,
              expected_gain: wonder[:information_gain], reward: reward,
              domain: resolved[:domain], resolution_rate: wonder_store.resolution_rate.round(3) }
          end

          def format_wonder(wonder)
            { wonder_id: wonder[:wonder_id], question: wonder[:question], domain: wonder[:domain],
              gap_type: wonder[:gap_type], score: Helpers::Wonder.score(wonder).round(3),
              attempts: wonder[:attempts], explorable: Helpers::Wonder.explorable?(wonder),
              created_at: wonder[:created_at] }
          end

          def format_agenda_item(wonder)
            { type: :curious, source: :curiosity, weight: Helpers::Wonder.score(wonder),
              summary: wonder[:question],
              metadata: { wonder_id: wonder[:wonder_id], domain: wonder[:domain], gap_type: wonder[:gap_type] } }
          end

          def compute_intensity
            active = wonder_store.active_count
            return 0.0 if active.zero?

            fullness = active.to_f / Helpers::Constants::MAX_WONDERS
            avg_salience = wonder_store.active_wonders.sum { |w| w[:salience] } / active
            explorable = wonder_store.active_wonders.count { |w| Helpers::Wonder.explorable?(w) }
            ((fullness * 0.3) + (avg_salience * 0.4) + ((explorable.to_f / active) * 0.3)).clamp(0.0, 1.0)
          end

          def top_curiosity_domain
            groups = wonder_store.active_wonders.group_by { |w| w[:domain] }
            return nil if groups.empty?

            groups.max_by { |_, wonders| wonders.sum { |w| Helpers::Wonder.score(w) } }&.first
          end

          def duplicate_wonder?(gap)
            wonder_store.active_wonders.any? do |existing|
              existing[:domain] == gap[:domain] && existing[:gap_type] == gap[:gap_type] &&
                existing[:question] == gap[:question]
            end
          end
        end
      end
    end
  end
end
