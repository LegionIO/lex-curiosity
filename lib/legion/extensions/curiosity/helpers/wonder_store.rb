# frozen_string_literal: true

module Legion
  module Extensions
    module Curiosity
      module Helpers
        # In-memory priority queue for wonder items with domain balancing and decay.
        class WonderStore
          attr_reader :resolved_count, :total_generated

          def initialize
            @wonders = {}
            @resolved_count = 0
            @total_generated = 0
            @domain_resolution_rates = Hash.new { |h, k| h[k] = { resolved: 0, total: 0 } }
          end

          def store(wonder)
            prune_if_full
            @wonders[wonder[:wonder_id]] = wonder
            @total_generated += 1
            @domain_resolution_rates[wonder[:domain]][:total] += 1
            wonder
          end

          def get(wonder_id)
            @wonders[wonder_id]
          end

          def update(wonder_id, attrs)
            wonder = @wonders[wonder_id]
            return nil unless wonder

            @wonders[wonder_id] = wonder.merge(attrs)
          end

          def delete(wonder_id)
            @wonders.delete(wonder_id)
          end

          def active_wonders
            @wonders.values.reject { |w| w[:resolved] }
          end

          def resolved_wonders
            @wonders.values.select { |w| w[:resolved] }
          end

          def top(limit: 5, exclude_domains: [])
            active_wonders
              .reject { |w| exclude_domains.include?(w[:domain]) }
              .sort_by { |w| -Wonder.score(w) }
              .first(limit)
          end

          def top_balanced(limit: 5)
            domain_counts = active_wonders.group_by { |w| w[:domain] }
                                          .transform_values(&:size)
            max_domain = domain_counts.values.max || 1

            active_wonders
              .sort_by do |w|
                domain_penalty = (domain_counts[w[:domain]].to_f / max_domain) * Constants::DOMAIN_BALANCE_FACTOR
                -(Wonder.score(w) - domain_penalty)
              end
              .first(limit)
          end

          def by_domain(domain)
            active_wonders.select { |w| w[:domain] == domain.to_sym }
          end

          def mark_resolved(wonder_id, resolution:, actual_gain: 0.5)
            wonder = @wonders[wonder_id]
            return nil unless wonder

            @wonders[wonder_id] = wonder.merge(
              resolved:    true,
              resolution:  resolution,
              actual_gain: actual_gain
            )
            @resolved_count += 1
            @domain_resolution_rates[wonder[:domain]][:resolved] += 1
            @wonders[wonder_id]
          end

          def decay_all(hours_elapsed: 1.0)
            pruned = 0
            @wonders.each do |id, wonder|
              next if wonder[:resolved]

              decayed = Wonder.decay_salience(wonder, hours_elapsed: hours_elapsed)
              if decayed[:salience] <= 0.0 || Wonder.stale?(decayed)
                @wonders.delete(id)
                pruned += 1
              else
                @wonders[id] = decayed
              end
            end
            pruned
          end

          def count
            @wonders.size
          end

          def active_count
            active_wonders.size
          end

          def domain_stats
            stats = Hash.new { |h, k| h[k] = { active: 0, resolved: 0 } }
            @wonders.each_value do |w|
              key = w[:resolved] ? :resolved : :active
              stats[w[:domain]][key] += 1
            end
            stats
          end

          def resolution_rate
            return 0.0 if @total_generated.zero?

            @resolved_count.to_f / @total_generated
          end

          def domain_resolution_rate(domain)
            rates = @domain_resolution_rates[domain.to_sym]
            return 0.0 if rates[:total].zero?

            rates[:resolved].to_f / rates[:total]
          end

          private

          def prune_if_full
            return unless active_count >= Constants::MAX_WONDERS

            lowest = active_wonders.min_by { |w| Wonder.score(w) }
            @wonders.delete(lowest[:wonder_id]) if lowest
          end
        end
      end
    end
  end
end
