module EY
  class CLI
    class ExtraHelp
      class << self

        def [](keyword)
          topics.find {|t| t.keyword == keyword }
        end

        def topics
          [Topic.new(
            'ey.yml',
            'Customizing the deploy process with config/ey.yml'
              ),
            ]
        end

      end

      class Topic < Struct.new(:keyword, :short_description)
        def long_help
          File.read(long_help_file)
        end

        private
        def long_help_file
          File.join(File.dirname(__FILE__), 'extra_help', 'texts', "#{keyword}.txt")
        end
      end

    end
  end
end
