# frozen_string_literal: true

require 'legion/extensions/curiosity/version'
require 'legion/extensions/curiosity/helpers/constants'
require 'legion/extensions/curiosity/helpers/wonder'
require 'legion/extensions/curiosity/helpers/wonder_store'
require 'legion/extensions/curiosity/helpers/gap_detector'
require 'legion/extensions/curiosity/runners/curiosity'
require 'legion/extensions/curiosity/client'

module Legion
  module Extensions
    # Intrinsic curiosity engine — knowledge gap detection, wonder lifecycle, curiosity-driven learning.
    module Curiosity
      extend Legion::Extensions::Core if Legion::Extensions.const_defined? :Core
    end
  end
end
