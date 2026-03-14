# lex-curiosity

Intrinsic curiosity engine for the LegionIO brain-modeled cognitive architecture.

## What It Does

Models the dopaminergic curiosity/reward system — the intrinsic motivation to explore knowledge gaps. The agent doesn't just process information when presented; it actively wonders about what it doesn't know and seeks to learn.

Two forms of curiosity:
- **Diversive curiosity**: general scanning for novelty (high-novelty, low-familiarity signals)
- **Specific curiosity**: focused pursuit of a particular knowledge gap (low-confidence predictions, contradictions)

## Core Concept: The Wonder

A "wonder" is a structured curiosity item — a question the agent has generated about a gap in its knowledge.

```ruby
client = Legion::Extensions::Curiosity::Client.new

# Detect gaps from tick phase results
result = client.detect_gaps(prior_results: {
  memory_retrieval: { traces: [], domain: :kubernetes },
  prediction_engine: { confidence: 0.3, domain: :vault }
})
# => { gaps_detected: 2, wonders_created: 2, curiosity_intensity: 0.15, ... }

# Manually generate a wonder
wonder = client.generate_wonder(
  question: "How does Consul ACL token inheritance work?",
  domain: :consul,
  gap_type: :incomplete
)

# Explore and resolve
client.explore_wonder(wonder_id: wonder[:wonder_id])
client.resolve_wonder(
  wonder_id: wonder[:wonder_id],
  resolution: "Child tokens inherit parent policy",
  actual_gain: 0.8
)
```

## Gap Types

| Type | Trigger |
|------|---------|
| `:unknown` | Domain with no memory traces |
| `:uncertain` | Low-confidence predictions |
| `:contradictory` | Conflicting memory traces |
| `:incomplete` | Partial pattern matches |

## Integration

Wires into two previously-unwired tick phases:
- `working_memory_integration` → `detect_gaps`
- `agenda_formation` → `form_agenda` (dream cycle)

## Development

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

## License

MIT
