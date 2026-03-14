# frozen_string_literal: true

module Legion
  module Extensions
    module Curiosity
      module Helpers
        module Constants
          GAP_TYPES = %i[unknown uncertain contradictory incomplete].freeze

          MAX_WONDERS                  = 20
          WONDER_DECAY_RATE            = 0.02    # salience decay per hour
          WONDER_STALE_THRESHOLD       = 259_200 # 3 days in seconds
          MAX_EXPLORATION_ATTEMPTS     = 5
          INFORMATION_GAIN_THRESHOLD   = 0.3     # minimum expected gain to create wonder
          CURIOSITY_REWARD_MULTIPLIER  = 1.5     # emotional reward on resolution
          DOMAIN_BALANCE_FACTOR        = 0.7     # penalize overrepresented domains
          DIVERSIVE_NOVELTY_THRESHOLD  = 0.6     # novelty above which diversive curiosity triggers
          SPECIFIC_GAP_THRESHOLD       = 0.5     # gap score above which specific curiosity triggers
          EXPLORATION_COOLDOWN         = 300     # seconds between re-exploration of same wonder
          LOW_CONFIDENCE_THRESHOLD     = 0.5     # prediction confidence below this triggers wonder
          EMPTY_RETRIEVAL_THRESHOLD    = 2       # fewer traces than this = unknown domain
        end
      end
    end
  end
end
