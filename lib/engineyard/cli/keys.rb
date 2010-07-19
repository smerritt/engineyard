module EY
  class CLI
    class Keys < EY::Thor
      # desc "add --file/-f PATH [--name/-n NAME --environment/-e ENVIRONMENT]",
      #   "Add an ssh public key to your account, optionally specifying an destination environment."
      # method_option :environment, :type => :string, :aliases => %w(-e),
      #   :desc => "Environment on which to take down the maintenance page"
      # method_option :verbose, :type => :boolean, :aliases => %w(-v),
      #   :desc => "Be verbose"
      # def add
      #   app         = fetch_app(options[:app])
      #   environment = fetch_environment(options[:environment], app)
      #   EY.ui.info "Taking down maintenance page for '#{app.name}' in '#{environment.name}'"
      # end

      desc "list", "Show ssh keys on your account or an environment"
      method_option :environment, :type => :string, :aliases => %w(-e),
        :desc => "Environment of which to show keys"
      method_option :all, :type => :boolean,
        :desc => "Show all keys"
      def list
        if options[:all]
          print_table api.keys.map { |key| [key.name, key.fingerprint] },
            :colwidth => api.keys.map{|k| k.name.length}.max
        else
          env = fetch_environment(options[:environment])
          key_table = env.keys.map do |key|
            [key.name, key.fingerprint]
          end
          print_table key_table, :truncate => false, :colwidth => env.keys.map{|k| k.name.length}.max
        end
      end
    end
  end
end
