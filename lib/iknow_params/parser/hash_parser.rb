require "active_support/core_ext/hash/indifferent_access"

# Simple wrapper to use IknowParams::Parser to extract and verify content from
# an arbitrary hash
class IknowParams::Parser::HashParser
  include IknowParams::Parser

  attr_reader :params

  def initialize(view_hash)
    @params = ActiveSupport::HashWithIndifferentAccess.new(view_hash)
  end

  def parse(&block)
    instance_exec(&block)
  end
end
