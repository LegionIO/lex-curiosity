# frozen_string_literal: true

RSpec.describe Legion::Extensions::Curiosity::Helpers::WonderStore do
  subject(:store) { described_class.new }

  let(:wonder) do
    Legion::Extensions::Curiosity::Helpers::Wonder.new_wonder(
      question: 'Why does this fail?',
      domain:   :terraform,
      gap_type: :uncertain,
      salience: 0.8
    )
  end

  describe '#store' do
    it 'stores and retrieves a wonder' do
      store.store(wonder)
      expect(store.get(wonder[:wonder_id])).to eq(wonder)
    end

    it 'increments total_generated' do
      store.store(wonder)
      expect(store.total_generated).to eq(1)
    end

    it 'prunes lowest-scored wonder when full' do
      low_wonder = Legion::Extensions::Curiosity::Helpers::Wonder.new_wonder(
        question: 'low priority', salience: 0.01, information_gain: 0.01
      )
      store.store(low_wonder)

      Legion::Extensions::Curiosity::Helpers::Constants::MAX_WONDERS.times do |i|
        w = Legion::Extensions::Curiosity::Helpers::Wonder.new_wonder(
          question: "wonder #{i}", salience: 0.9
        )
        store.store(w)
      end

      expect(store.get(low_wonder[:wonder_id])).to be_nil
    end
  end

  describe '#active_wonders and #resolved_wonders' do
    it 'separates active from resolved' do
      store.store(wonder)
      expect(store.active_wonders.size).to eq(1)
      expect(store.resolved_wonders.size).to eq(0)

      store.mark_resolved(wonder[:wonder_id], resolution: 'found the answer')
      expect(store.active_wonders.size).to eq(0)
      expect(store.resolved_wonders.size).to eq(1)
    end
  end

  describe '#top_balanced' do
    it 'returns wonders sorted by score with domain balancing' do
      3.times do |i|
        w = Legion::Extensions::Curiosity::Helpers::Wonder.new_wonder(
          question: "terraform #{i}", domain: :terraform, salience: 0.8
        )
        store.store(w)
      end

      other = Legion::Extensions::Curiosity::Helpers::Wonder.new_wonder(
        question: 'vault question', domain: :vault, salience: 0.7
      )
      store.store(other)

      top = store.top_balanced(limit: 2)
      domains = top.map { |w| w[:domain] }
      expect(domains).to include(:vault)
    end
  end

  describe '#mark_resolved' do
    it 'marks wonder as resolved with resolution text' do
      store.store(wonder)
      resolved = store.mark_resolved(wonder[:wonder_id], resolution: 'TTL was 30 minutes', actual_gain: 0.8)
      expect(resolved[:resolved]).to be true
      expect(resolved[:resolution]).to eq('TTL was 30 minutes')
      expect(store.resolved_count).to eq(1)
    end

    it 'returns nil for unknown wonder' do
      expect(store.mark_resolved('nonexistent', resolution: 'nope')).to be_nil
    end
  end

  describe '#decay_all' do
    it 'reduces salience and prunes exhausted wonders' do
      low = Legion::Extensions::Curiosity::Helpers::Wonder.new_wonder(
        question: 'fading', salience: 0.01
      )
      store.store(low)
      pruned = store.decay_all(hours_elapsed: 10.0)
      expect(pruned).to eq(1)
      expect(store.get(low[:wonder_id])).to be_nil
    end

    it 'preserves resolved wonders' do
      store.store(wonder)
      store.mark_resolved(wonder[:wonder_id], resolution: 'done')
      store.decay_all(hours_elapsed: 1000.0)
      expect(store.get(wonder[:wonder_id])).not_to be_nil
    end
  end

  describe '#domain_stats' do
    it 'reports per-domain counts' do
      store.store(wonder)
      w2 = Legion::Extensions::Curiosity::Helpers::Wonder.new_wonder(
        question: 'another', domain: :terraform
      )
      store.store(w2)
      store.mark_resolved(w2[:wonder_id], resolution: 'resolved')

      stats = store.domain_stats
      expect(stats[:terraform][:active]).to eq(1)
      expect(stats[:terraform][:resolved]).to eq(1)
    end
  end

  describe '#resolution_rate' do
    it 'returns 0.0 when no wonders generated' do
      expect(store.resolution_rate).to eq(0.0)
    end

    it 'computes fraction of resolved wonders' do
      store.store(wonder)
      w2 = Legion::Extensions::Curiosity::Helpers::Wonder.new_wonder(question: 'other')
      store.store(w2)
      store.mark_resolved(wonder[:wonder_id], resolution: 'done')
      expect(store.resolution_rate).to eq(0.5)
    end
  end
end
