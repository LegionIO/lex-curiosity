# frozen_string_literal: true

RSpec.describe Legion::Extensions::Curiosity::Client do
  subject(:client) { described_class.new }

  it 'initializes with a default wonder store' do
    expect(client.wonder_store).to be_a(Legion::Extensions::Curiosity::Helpers::WonderStore)
  end

  it 'accepts an injected store' do
    custom_store = Legion::Extensions::Curiosity::Helpers::WonderStore.new
    client = described_class.new(store: custom_store)
    expect(client.wonder_store).to be(custom_store)
  end

  it 'includes the Curiosity runner' do
    expect(client).to respond_to(:detect_gaps)
    expect(client).to respond_to(:generate_wonder)
    expect(client).to respond_to(:explore_wonder)
    expect(client).to respond_to(:resolve_wonder)
    expect(client).to respond_to(:curiosity_intensity)
    expect(client).to respond_to(:top_wonders)
    expect(client).to respond_to(:form_agenda)
    expect(client).to respond_to(:wonder_stats)
    expect(client).to respond_to(:decay_wonders)
  end
end
