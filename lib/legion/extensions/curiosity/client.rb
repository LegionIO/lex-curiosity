# frozen_string_literal: true

require 'legion/extensions/curiosity/helpers/constants'
require 'legion/extensions/curiosity/helpers/wonder'
require 'legion/extensions/curiosity/helpers/wonder_store'
require 'legion/extensions/curiosity/helpers/gap_detector'
require 'legion/extensions/curiosity/runners/curiosity'

module Legion
  module Extensions
    module Curiosity
      # Standalone client for curiosity operations without the full framework.
      class Client
        include Runners::Curiosity

        attr_reader :wonder_store

        def initialize(store: nil, **)
          @wonder_store = store || Helpers::WonderStore.new
        end
      end
    end
  end
end
