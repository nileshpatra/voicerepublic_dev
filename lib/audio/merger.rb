require File.expand_path('../merge_strategy', __FILE__)

# stream merging logic refactored for testability
#
# use static
#
#   Audio::Merger.run('/path/to/recordings')
#   Audio::Merger.run('/path/to/recordings', 'MergeStrategy::Experimental')
#
# use instanciation (to run multiple strategies)
#
#   merger = Audio::Merger.new('/path/to/recordings')
#   merger.run
#
# or
#
#   merger.run('Audio::MergeStrategy::Experimental')
#
module Audio
  class Merger < Struct.new(:base)

    class << self

      def run(base, strategy=nil)
        new(base).run(strategy)
      end

      # the following two methods are basically helpers for specs
      # and helpers for the legacy system., which does not yet
      # write journals
      def fake_journal(path, name)
        # FIXME implicit assumption about filenames
        flvs = Dir.glob("#{path}/t#{name}-*.flv").sort
        result = flvs.map do |flv|
          _, basename, timestamp = flv.match(/.*\/(.*?(\d+)\.flv)/).to_a
          ['record_done', basename, timestamp] * ' '
        end
        result * "\n"
      end

      def generate_fake_journal(path, name)
        File.open("#{path}/#{name}.journal", 'w') do |f|
          f.puts fake_journal(path, name)
        end
      end

    end

    DEFAULT_STRATEGY = ::Audio::MergeStrategy::Kluuu

    def run(strategy=nil)
      if strategy.is_a?(String)
        name = "Audio::MergeStrategy::#{strategy.camelize}"
        begin
          strategy = Kernel.const_get(name)
        rescue NameError
          puts "#{name} not found, using default strategy" +
            " #{DEFAULT_STRATEGY} as fallback."
          strategy = nil
        end
      end
      strategy ||= DEFAULT_STRATEGY
      strategy.call(base)
    end

  end
end

# args are path, strategy
Audio::Merger.run(*ARGV) if __FILE__==$0
