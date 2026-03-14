# frozen_string_literal: true

require 'securerandom'

module Legion
  module Extensions
    module Curiosity
      module Helpers
        module Wonder
          module_function

          def new_wonder(question:, domain: :general, gap_type: :unknown,
                         salience: 0.5, information_gain: 0.5,
                         source_trace_ids: [], emotional_valence: {})
            raise ArgumentError, "invalid gap_type: #{gap_type}" unless Constants::GAP_TYPES.include?(gap_type)

            {
              wonder_id:         SecureRandom.uuid,
              question:          question,
              domain:            domain.to_sym,
              gap_type:          gap_type,
              salience:          salience.clamp(0.0, 1.0),
              information_gain:  information_gain.clamp(0.0, 1.0),
              attempts:          0,
              created_at:        Time.now.utc,
              last_explored_at:  nil,
              resolved:          false,
              resolution:        nil,
              source_trace_ids:  Array(source_trace_ids),
              emotional_valence: emotional_valence
            }
          end

          def score(wonder)
            return 0.0 if wonder[:resolved]

            base = (wonder[:salience] * 0.6) + (wonder[:information_gain] * 0.4)
            attempt_penalty = [wonder[:attempts] * 0.1, 0.5].min
            base - attempt_penalty
          end

          def stale?(wonder)
            age = Time.now.utc - wonder[:created_at]
            age > Constants::WONDER_STALE_THRESHOLD
          end

          def explorable?(wonder)
            return false if wonder[:resolved]
            return false if wonder[:attempts] >= Constants::MAX_EXPLORATION_ATTEMPTS

            if wonder[:last_explored_at]
              cooldown = Constants::EXPLORATION_COOLDOWN * (2**[wonder[:attempts] - 1, 0].max)
              return false if (Time.now.utc - wonder[:last_explored_at]) < cooldown
            end

            true
          end

          def decay_salience(wonder, hours_elapsed: 1.0)
            return wonder if wonder[:resolved]

            decayed = wonder[:salience] - (Constants::WONDER_DECAY_RATE * hours_elapsed)
            wonder.merge(salience: [decayed, 0.0].max)
          end
        end
      end
    end
  end
end
