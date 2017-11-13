 # Simple wrapper to use IknowParams::Parser to extract and verify content from
 # an arbitrary hash
class IknowParams::Parser::HashParser
  include IknowParams::Parser

  attr_reader :params

  def initialize(view_hash)
    @params = view_hash
  end

  def parse(&block)
    instance_exec(&block)
  end
end
