# frozen_string_literal: true

RSpec.describe Legion::Extensions::Curiosity::Helpers::GapDetector do
  describe '.detect' do
    context 'with empty prior results' do
      it 'returns empty array' do
        expect(described_class.detect({})).to eq([])
      end
    end

    context 'with memory gaps' do
      it 'detects unknown domain when few traces returned' do
        prior = {
          memory_retrieval: { traces: [], domain: :kubernetes }
        }
        gaps = described_class.detect(prior)
        expect(gaps.size).to be >= 1
        unknown = gaps.find { |g| g[:gap_type] == :unknown }
        expect(unknown).not_to be_nil
        expect(unknown[:domain]).to eq(:kubernetes)
      end

      it 'detects incomplete knowledge with low-strength traces' do
        prior = {
          memory_retrieval: {
            traces: [
              { trace_id: 'a', strength: 0.1 },
              { trace_id: 'b', strength: 0.2 },
              { trace_id: 'c', strength: 0.9 }
            ],
            domain: :consul
          }
        }
        gaps = described_class.detect(prior)
        incomplete = gaps.find { |g| g[:gap_type] == :incomplete }
        expect(incomplete).not_to be_nil
        expect(incomplete[:source_trace_ids]).to contain_exactly('a', 'b')
      end
    end

    context 'with prediction gaps' do
      it 'detects low-confidence predictions' do
        prior = {
          prediction_engine: { confidence: 0.3, domain: :vault }
        }
        gaps = described_class.detect(prior)
        uncertain = gaps.find { |g| g[:gap_type] == :uncertain }
        expect(uncertain).not_to be_nil
        expect(uncertain[:domain]).to eq(:vault)
      end

      it 'detects failed predictions' do
        prior = {
          prediction_engine: { status: :failed, domain: :terraform }
        }
        gaps = described_class.detect(prior)
        uncertain = gaps.find { |g| g[:gap_type] == :uncertain }
        expect(uncertain).not_to be_nil
        expect(uncertain[:salience]).to eq(0.8)
      end
    end

    context 'with emotional gaps' do
      it 'detects novel unfamiliar stimuli' do
        prior = {
          emotional_evaluation: {
            valence: { novelty: 0.9, familiarity: 0.1 },
            domain:  :new_domain
          }
        }
        gaps = described_class.detect(prior)
        unknown = gaps.find { |g| g[:gap_type] == :unknown }
        expect(unknown).not_to be_nil
        expect(unknown[:salience]).to eq(0.9)
      end

      it 'does not trigger for familiar novel stimuli' do
        prior = {
          emotional_evaluation: {
            valence: { novelty: 0.9, familiarity: 0.8 }
          }
        }
        gaps = described_class.detect(prior)
        expect(gaps.select { |g| g[:gap_type] == :unknown }).to be_empty
      end
    end

    context 'with contradiction gaps' do
      it 'detects active conflicts' do
        prior = {
          contradiction_resolution: {
            active_conflicts: [
              { domain: :vault, trace_ids: %w[x y] }
            ]
          }
        }
        gaps = described_class.detect(prior)
        contradictory = gaps.find { |g| g[:gap_type] == :contradictory }
        expect(contradictory).not_to be_nil
        expect(contradictory[:domain]).to eq(:vault)
      end
    end

    context 'with information gain threshold' do
      it 'filters out low-gain gaps' do
        prior = {
          memory_retrieval: { traces: [{ trace_id: 'a', strength: 0.25 }], domain: :general }
        }
        gaps = described_class.detect(prior)
        # The incomplete gap has info gain 0.5 which is above threshold
        # But there may be low-gain gaps filtered out
        gaps.each do |g|
          expect(g[:information_gain]).to be >= Legion::Extensions::Curiosity::Helpers::Constants::INFORMATION_GAIN_THRESHOLD
        end
      end
    end
  end
end
