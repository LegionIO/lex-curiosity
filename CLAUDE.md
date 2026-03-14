# lex-curiosity

**Level 3 Documentation** — Parent: `/Users/miverso2/rubymine/legion/extensions-agentic/CLAUDE.md`

## Purpose

Intrinsic curiosity engine for the LegionIO cognitive architecture. Detects knowledge gaps from tick phase results, generates structured "wonder" items representing questions the agent has about what it doesn't know, and manages a priority queue of wonders with domain balancing and salience decay.

Implements both diversive curiosity (novelty-seeking) and specific curiosity (gap-filling). Wonders drive the agent's exploration agenda.

## Gem Info

- **Gem name**: `lex-curiosity`
- **Version**: `0.1.0`
- **Namespace**: `Legion::Extensions::Curiosity`
- **Location**: `extensions-agentic/lex-curiosity/`

## File Structure

```
lib/legion/extensions/curiosity/
  curiosity.rb                  # Top-level requires
  version.rb                    # VERSION = '0.1.0'
  client.rb                     # Client class with @wonder_store
  helpers/
    constants.rb                # GAP_TYPES, thresholds, decay rates
    wonder.rb                   # Wonder module: factory, score, stale?, explorable?, decay_salience
    wonder_store.rb             # Priority queue with domain balancing and decay
    gap_detector.rb             # Module: detects gaps from tick phase result hashes
  runners/
    curiosity.rb                # Runner module: all public methods
```

## Key Constants

| Constant | Value | Purpose |
|---|---|---|
| `GAP_TYPES` | `[:unknown, :uncertain, :contradictory, :incomplete]` | Types of knowledge gaps |
| `MAX_WONDERS` | 20 | Max active wonders in priority queue |
| `WONDER_DECAY_RATE` | 0.02 | Salience decay per hour |
| `WONDER_STALE_THRESHOLD` | 259_200 (3 days) | Seconds until wonder is pruned |
| `MAX_EXPLORATION_ATTEMPTS` | 5 | Max attempts before wonder is retired |
| `INFORMATION_GAIN_THRESHOLD` | 0.3 | Min gain to create a wonder from a gap |
| `CURIOSITY_REWARD_MULTIPLIER` | 1.5 | Emotional reward on wonder resolution |
| `DOMAIN_BALANCE_FACTOR` | 0.7 | Penalty for overrepresented domains |
| `LOW_CONFIDENCE_THRESHOLD` | 0.5 | Prediction confidence below this triggers wonder |
| `EMPTY_RETRIEVAL_THRESHOLD` | 2 | Fewer traces than this = unknown domain gap |

## Runners

All methods in `Legion::Extensions::Curiosity::Runners::Curiosity`.

| Method | Key Args | Returns |
|---|---|---|
| `detect_gaps` | `prior_results: {}` | `{ gaps_detected:, wonders_created:, curiosity_intensity:, top_wonders:, active_count: }` |
| `generate_wonder` | `question:, domain:, gap_type:, salience:, information_gain:, source_trace_ids:` | wonder hash |
| `explore_wonder` | `wonder_id:` | `{ exploring:, wonder_id:, attempt: }` or error |
| `resolve_wonder` | `wonder_id:, resolution:, actual_gain:` | `{ resolved:, actual_gain:, reward:, resolution_rate: }` |
| `curiosity_intensity` | — | `{ intensity:, active_wonders:, resolution_rate:, top_domain: }` |
| `top_wonders` | `limit: 5` | `{ wonders: }` |
| `form_agenda` | — | `{ agenda_items:, source: :curiosity }` |
| `wonder_stats` | — | Full stats hash |
| `decay_wonders` | `hours_elapsed: 1.0` | `{ pruned:, remaining: }` |

## Helpers

### `Wonder` (module)
Factory and utility functions. `new_wonder(question:, domain:, gap_type:, salience:, information_gain:, source_trace_ids:)` returns a hash. `score(wonder)` = `(salience * 0.6) + (information_gain * 0.4) - attempt_penalty`. `stale?`, `explorable?` (checks attempts and cooldown), `decay_salience`.

### `WonderStore`
Priority queue backed by a hash. Key methods: `store(wonder)`, `get(wonder_id)`, `update(wonder_id, attrs)`, `top(limit:)`, `top_balanced(limit:)` (domain-balanced), `mark_resolved(wonder_id, resolution:, actual_gain:)`, `decay_all(hours_elapsed:)`, `domain_stats`, `resolution_rate`, `domain_resolution_rate(domain)`.

### `GapDetector` (module)
Stateless. `detect(prior_results)` examines four keys: `:memory_retrieval`, `:prediction_engine`, `:emotional_evaluation`, `:contradiction_resolution`. Returns array of gap hashes sorted by composite score. Filters below `INFORMATION_GAIN_THRESHOLD`.

## Integration Points

- `detect_gaps` is called from lex-tick with the full prior phase results hash
- `form_agenda` outputs agenda items for the lex-tick agenda formation phase
- `curiosity_intensity` provides a scalar signal to lex-emotion
- `resolve_wonder` reward can feed lex-emotion valence
- Wonder `source_trace_ids` links back to lex-memory traces

## Development Notes

- `WonderStore` uses a `Hash.new { |h,k| h[k] = ... }` for domain resolution rates
- Exploration cooldown uses exponential backoff: `300 * 2^(attempts - 1)`
- `top_balanced` penalizes overrepresented domains using `DOMAIN_BALANCE_FACTOR`
- Duplicate wonders are detected by matching `domain + gap_type + question`
