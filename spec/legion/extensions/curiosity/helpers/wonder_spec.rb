# frozen_string_literal: true

RSpec.describe Legion::Extensions::Curiosity::Helpers::Wonder do
  describe '.new_wonder' do
    it 'creates a wonder with required fields' do
      wonder = described_class.new_wonder(question: 'Why is the sky blue?')
      expect(wonder[:wonder_id]).to be_a(String)
      expect(wonder[:question]).to eq('Why is the sky blue?')
      expect(wonder[:domain]).to eq(:general)
      expect(wonder[:gap_type]).to eq(:unknown)
      expect(wonder[:salience]).to eq(0.5)
      expect(wonder[:information_gain]).to eq(0.5)
      expect(wonder[:attempts]).to eq(0)
      expect(wonder[:resolved]).to be false
      expect(wonder[:created_at]).to be_a(Time)
    end

    it 'accepts custom fields' do
      wonder = described_class.new_wonder(
        question:         'Why do predictions fail here?',
        domain:           :terraform,
        gap_type:         :uncertain,
        salience:         0.9,
        information_gain: 0.8,
        source_trace_ids: ['abc-123']
      )
      expect(wonder[:domain]).to eq(:terraform)
      expect(wonder[:gap_type]).to eq(:uncertain)
      expect(wonder[:salience]).to eq(0.9)
      expect(wonder[:source_trace_ids]).to eq(['abc-123'])
    end

    it 'clamps salience to [0.0, 1.0]' do
      wonder = described_class.new_wonder(question: 'test', salience: 1.5)
      expect(wonder[:salience]).to eq(1.0)
    end

    it 'raises on invalid gap_type' do
      expect { described_class.new_wonder(question: 'test', gap_type: :invalid) }
        .to raise_error(ArgumentError, /invalid gap_type/)
    end

    it 'converts domain to symbol' do
      wonder = described_class.new_wonder(question: 'test', domain: 'vault')
      expect(wonder[:domain]).to eq(:vault)
    end
  end

  describe '.score' do
    it 'combines salience and information gain' do
      wonder = described_class.new_wonder(question: 'test', salience: 1.0, information_gain: 1.0)
      expect(described_class.score(wonder)).to eq(1.0)
    end

    it 'returns 0.0 for resolved wonders' do
      wonder = described_class.new_wonder(question: 'test').merge(resolved: true)
      expect(described_class.score(wonder)).to eq(0.0)
    end

    it 'applies attempt penalty' do
      wonder = described_class.new_wonder(question: 'test', salience: 1.0, information_gain: 1.0)
      score_fresh = described_class.score(wonder)
      score_tried = described_class.score(wonder.merge(attempts: 3))
      expect(score_tried).to be < score_fresh
    end

    it 'caps attempt penalty at 0.5' do
      wonder = described_class.new_wonder(question: 'test', salience: 1.0, information_gain: 1.0)
      score = described_class.score(wonder.merge(attempts: 100))
      expect(score).to eq(0.5)
    end
  end

  describe '.stale?' do
    it 'returns false for recent wonders' do
      wonder = described_class.new_wonder(question: 'test')
      expect(described_class.stale?(wonder)).to be false
    end

    it 'returns true for old wonders' do
      old_time = Time.now.utc - (Legion::Extensions::Curiosity::Helpers::Constants::WONDER_STALE_THRESHOLD + 1)
      wonder = described_class.new_wonder(question: 'test').merge(created_at: old_time)
      expect(described_class.stale?(wonder)).to be true
    end
  end

  describe '.explorable?' do
    it 'returns true for fresh wonders' do
      wonder = described_class.new_wonder(question: 'test')
      expect(described_class.explorable?(wonder)).to be true
    end

    it 'returns false for resolved wonders' do
      wonder = described_class.new_wonder(question: 'test').merge(resolved: true)
      expect(described_class.explorable?(wonder)).to be false
    end

    it 'returns false when max attempts reached' do
      wonder = described_class.new_wonder(question: 'test')
                              .merge(attempts: Legion::Extensions::Curiosity::Helpers::Constants::MAX_EXPLORATION_ATTEMPTS)
      expect(described_class.explorable?(wonder)).to be false
    end

    it 'respects exploration cooldown' do
      wonder = described_class.new_wonder(question: 'test')
                              .merge(attempts: 1, last_explored_at: Time.now.utc)
      expect(described_class.explorable?(wonder)).to be false
    end
  end

  describe '.decay_salience' do
    it 'reduces salience over time' do
      wonder = described_class.new_wonder(question: 'test', salience: 1.0)
      decayed = described_class.decay_salience(wonder, hours_elapsed: 5.0)
      expect(decayed[:salience]).to be < 1.0
    end

    it 'does not go below 0.0' do
      wonder = described_class.new_wonder(question: 'test', salience: 0.01)
      decayed = described_class.decay_salience(wonder, hours_elapsed: 100.0)
      expect(decayed[:salience]).to eq(0.0)
    end

    it 'skips resolved wonders' do
      wonder = described_class.new_wonder(question: 'test', salience: 1.0).merge(resolved: true)
      decayed = described_class.decay_salience(wonder, hours_elapsed: 100.0)
      expect(decayed[:salience]).to eq(1.0)
    end
  end
end
