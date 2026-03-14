# frozen_string_literal: true

RSpec.describe Legion::Extensions::Curiosity::Runners::Curiosity do
  let(:client) { Legion::Extensions::Curiosity::Client.new }

  describe '#detect_gaps' do
    it 'returns gap detection results' do
      result = client.detect_gaps(prior_results: {})
      expect(result[:gaps_detected]).to eq(0)
      expect(result[:wonders_created]).to eq(0)
      expect(result[:curiosity_intensity]).to eq(0.0)
    end

    it 'creates wonders from detected gaps' do
      prior = {
        memory_retrieval:  { traces: [], domain: :unknown_domain },
        prediction_engine: { confidence: 0.2, domain: :uncertain_domain }
      }
      result = client.detect_gaps(prior_results: prior)
      expect(result[:gaps_detected]).to be >= 2
      expect(result[:wonders_created]).to be >= 1
      expect(result[:curiosity_intensity]).to be > 0.0
    end

    it 'does not create duplicate wonders' do
      prior = {
        memory_retrieval: { traces: [], domain: :repeated }
      }
      client.detect_gaps(prior_results: prior)
      result = client.detect_gaps(prior_results: prior)
      expect(result[:wonders_created]).to eq(0)
    end
  end

  describe '#generate_wonder' do
    it 'manually creates a wonder' do
      wonder = client.generate_wonder(
        question: 'How does Consul ACL work?',
        domain:   :consul,
        gap_type: :unknown
      )
      expect(wonder[:wonder_id]).to be_a(String)
      expect(wonder[:question]).to eq('How does Consul ACL work?')
      expect(wonder[:domain]).to eq(:consul)
    end
  end

  describe '#explore_wonder' do
    let(:wonder) do
      client.generate_wonder(question: 'test?', domain: :test)
    end

    it 'marks a wonder as being explored' do
      result = client.explore_wonder(wonder_id: wonder[:wonder_id])
      expect(result[:exploring]).to be true
      expect(result[:attempt]).to eq(1)
    end

    it 'returns error for unknown wonder' do
      result = client.explore_wonder(wonder_id: 'nonexistent')
      expect(result[:error]).to eq(:not_found)
    end

    it 'returns error for resolved wonder' do
      client.resolve_wonder(wonder_id: wonder[:wonder_id], resolution: 'done')
      result = client.explore_wonder(wonder_id: wonder[:wonder_id])
      expect(result[:error]).to eq(:already_resolved)
    end
  end

  describe '#resolve_wonder' do
    let(:wonder) do
      client.generate_wonder(question: 'test?', domain: :test, information_gain: 0.7)
    end

    it 'resolves with reward calculation' do
      result = client.resolve_wonder(
        wonder_id:   wonder[:wonder_id],
        resolution:  'Found the answer in the docs',
        actual_gain: 0.8
      )
      expect(result[:resolved]).to be true
      expect(result[:actual_gain]).to eq(0.8)
      expect(result[:expected_gain]).to eq(0.7)
      expect(result[:reward]).to eq(0.8 * Legion::Extensions::Curiosity::Helpers::Constants::CURIOSITY_REWARD_MULTIPLIER)
    end

    it 'returns error for unknown wonder' do
      result = client.resolve_wonder(wonder_id: 'nope', resolution: 'x')
      expect(result[:error]).to eq(:not_found)
    end

    it 'returns error for already resolved wonder' do
      client.resolve_wonder(wonder_id: wonder[:wonder_id], resolution: 'first')
      result = client.resolve_wonder(wonder_id: wonder[:wonder_id], resolution: 'second')
      expect(result[:error]).to eq(:already_resolved)
    end
  end

  describe '#curiosity_intensity' do
    it 'returns 0.0 with no wonders' do
      result = client.curiosity_intensity
      expect(result[:intensity]).to eq(0.0)
    end

    it 'increases with more wonders' do
      5.times { |i| client.generate_wonder(question: "q#{i}?", domain: :test) }
      result = client.curiosity_intensity
      expect(result[:intensity]).to be > 0.0
      expect(result[:active_wonders]).to eq(5)
    end
  end

  describe '#top_wonders' do
    it 'returns top wonders by balanced score' do
      client.generate_wonder(question: 'high?', domain: :a, salience: 0.9)
      client.generate_wonder(question: 'low?', domain: :b, salience: 0.2)
      result = client.top_wonders(limit: 5)
      expect(result[:wonders].first[:question]).to eq('high?')
    end
  end

  describe '#form_agenda' do
    it 'converts top wonders to agenda items' do
      client.generate_wonder(question: 'Why?', domain: :test)
      result = client.form_agenda
      expect(result[:agenda_items].size).to eq(1)
      expect(result[:agenda_items].first[:type]).to eq(:curious)
      expect(result[:agenda_items].first[:source]).to eq(:curiosity)
    end

    it 'returns empty agenda with no wonders' do
      result = client.form_agenda
      expect(result[:agenda_items]).to be_empty
    end
  end

  describe '#wonder_stats' do
    it 'returns comprehensive statistics' do
      client.generate_wonder(question: 'q1?', domain: :a)
      w = client.generate_wonder(question: 'q2?', domain: :b)
      client.resolve_wonder(wonder_id: w[:wonder_id], resolution: 'done')

      stats = client.wonder_stats
      expect(stats[:total_generated]).to eq(2)
      expect(stats[:active]).to eq(1)
      expect(stats[:resolved]).to eq(1)
      expect(stats[:resolution_rate]).to eq(0.5)
    end
  end

  describe '#decay_wonders' do
    it 'prunes exhausted wonders' do
      client.generate_wonder(question: 'fading?', salience: 0.01)
      result = client.decay_wonders(hours_elapsed: 10.0)
      expect(result[:pruned]).to eq(1)
    end
  end
end
