require "log"
require "json"
require "socket"

require "./extensions/*"
require "./abstract_machine/**"

module AbstractMachine
  VERSION = {{ `shards version "#{__DIR__}"`.chomp.stringify }}
end
