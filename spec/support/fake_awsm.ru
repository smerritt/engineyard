require 'rubygems'
require 'sinatra/base'
require 'json'

class FakeAwsm < Sinatra::Base

  def initialize(*_)
    super
    # the class var is because the object passed to #run is #dup-ed on
    # every request. It makes sense; you hardly ever want to keep
    # state in your application object (accidentally or otherwise),
    # but in this situation that's exactly what we want to do.
    @@scenario = Scenario::Empty  # have to start somewhere
  end

  before { content_type "application/json" }

  get "/" do
    content_type :html
    "OMG"
  end

  put "/scenario" do
    new_scenario = case params[:scenario]
                   when "empty"
                     Scenario::Empty
                   when "one app, one environment, not linked"
                     Scenario::UnlinkedApp
                   when "two apps"
                     Scenario::TwoApps
                   when "one app, one environment"
                     Scenario::LinkedApp
                   when "one app, one environment, no instances"
                     Scenario::LinkedAppNotRunning
                   when "one app, one environment, app master red"
                     Scenario::LinkedAppRedMaster
                   when "one app, many environments"
                     Scenario::OneAppManyEnvs
                   when "one app, many similarly-named environments"
                     Scenario::OneAppManySimilarlyNamedEnvs
                   else
                     status(400)
                     return {"ok" => "false", "message" => "wtf is the #{params[:scenario]} scenario?"}.to_json
                   end
    @@scenario = new_scenario.new(params[:remote])
    {"ok" => "true"}.to_json
  end

  get "/api/v2/apps" do
    {"apps" => @@scenario.apps}.to_json
  end

  get "/api/v2/keypairs" do
    {"keypairs" => @@scenario.keypairs}.to_json
  end

  get "/api/v2/environments" do
    {"environments" => @@scenario.environments}.to_json
  end

  get "/api/v2/environments/:env_id/logs" do
    {"logs" => @@scenario.logs(params[:env_id].to_i)}.to_json
  end

  get "/api/v2/environments/:env_id/keypairs" do
    {"keypairs" => @@scenario.keys_for_env(params[:env_id].to_i)}.to_json
  end

  get "/api/v2/environments/:env_id/recipes" do
    redirect '/fakes3/recipe'
  end

  get "/fakes3/recipe" do
    content_type "binary/octet-stream"
    status(200)

    tempdir = File.join(Dir.tmpdir, "ey_test_cmds_#{Time.now.tv_sec}#{Time.now.tv_usec}_#{$$}")
    Dir.mkdir(tempdir)
    Dir.mkdir("#{tempdir}/cookbooks")
    File.open("#{tempdir}/cookbooks/README", 'w') do |f|
      f.write "Remove this file to clone an upstream git repository of cookbooks\n"
    end

    Dir.chdir(tempdir) { `tar czf - cookbooks` }
  end

  post "/api/v2/environments/:env_id/recipes" do
    if params[:file][:tempfile]
      files = `tar --list -z -f "#{params[:file][:tempfile].path}"`.split(/\n/)
      if files.empty?
        status(400)
        "No files in uploaded tarball"
      else
        status(204)
        ""
      end
    else
      status(400)
      "Recipe file not uploaded"
    end
  end

  put "/api/v2/environments/:env_id/rebuild" do
    status(202)
    ""
  end

  put "/api/v2/environments/:env_id/run_custom_recipes" do
    status(202)
    ""
  end

  post "/api/v2/authenticate" do
    if valid_user?
      {"api_token" => "deadbeef", "ok" => true}.to_json
    else
      status(401)
      {"ok" => false}.to_json
    end
  end

private

  def valid_user?
    params[:email] == "test@test.test" &&
      params[:password] == "test"
  end

  module Scenario
    class Base
      attr_accessor :git_remote

      def initialize(git_remote)
        self.git_remote = git_remote

        @apps, @envs, @keys, @app_joins, @key_joins =
          starting_apps, starting_environments, starting_keys,
          starting_app_joins, starting_key_joins
      end

      def apps
        @apps.dup.map do |app|
          app.merge("environments" => joined_envs(app))
        end
      end

      def environments
        @envs.dup.map do |env|
          env.merge("apps" => joined_apps(env))
        end
      end

      def keys
        @keys.dup
      end

      def keys_for_env(env_id)
        env = @envs.find {|e| e["id"] == env_id }
        related_objects(env, @keys, @key_joins.map{|j| j.reverse})
      end

      def logs(env_id)
        [{
            "id" => env_id,
            "role" => "app_master",
            "main" => "MAIN LOG OUTPUT",
            "custom" => "CUSTOM LOG OUTPUT"
          }]
      end

      private

      def starting_apps()         [] end
      def starting_environments() [] end
      def starting_keys()         [] end
      def starting_app_joins()    [] end
      def starting_key_joins()    [] end

      def joined_envs(app)
        related_objects(app, @envs, @app_joins)
      end

      def joined_apps(env)
        related_objects(env, @apps, @app_joins.map {|j| j.reverse})
      end

      def related_objects(obj, candidates, relation)
        candidate_table = candidates.inject({}) do |table, candidate|
          table.merge(candidate["id"] => candidate)
        end

        relation.find_all do |(obj_id, candidate_id)|
          obj["id"] == obj_id
        end.map do |(obj_id, candidate_id)|
          candidate_table[candidate_id]
        end
      end
    end

    class LinkedApp < Base
      private
      def _instances
        [{
            "id" => 27220,
            "role" => "app_master",
            "name" => nil,
            "status" => "running",
            "amazon_id" => 'i-ddbbdd92',
            "public_hostname" => "ec2-174-129-198-124.compute-1.amazonaws.com",
          }, {
            "id" => 22721,
            "name" => nil,
            "role" => "db_master",
            "status" => "running",
            "amazon_id" => "i-d4cdddbf",
            "public_hostname" => "ec2-174-129-142-53.compute-1.amazonaws.com",
          }, {
            "id" => 22722,
            "role" => "app",
            "name" => nil,
            "status" => "building",
            "amazon_id" => "i-d2e3f1b9",
            "public_hostname" => "ec2-72-44-46-66.compute-1.amazonaws.com",
          }, {
            "id" => 22723,
            "role" => "util",
            "name" => "fluffy",
            "status" => "running",
            "amazon_id" => "i-80e3f1eb",
            "public_hostname" => "ec2-184-73-116-228.compute-1.amazonaws.com",
          }]
      end

      def starting_apps
        [{
            "id" => 1001,
            "name" => "rails232app",
            "repository_uri" => git_remote}]
      end

      def starting_environments
        [{
            "id" => 200,
            "ssh_username" => "turkey",
            "instances" => _instances,
            "name" => "giblets",
            "instances_count" => 4,
            "stack_name" => "nginx_mongrel",
            "framework_env" => "production",
            "app_master" => _instances[0]}]
      end

      def starting_app_joins
        [[1001, 200]]
      end

      def starting_keys
        [{
            "id" => 3030,
            "name" => "id_dsa.pub",
            "public_key" => "ssh-dss AAAAB3NzaC1kc3MAAACBAOpTvNnhAZzl/LT7L2Oj2EQ3I4JMP0cwSwu+80zrNiWpChXcyIbLHDBQ76Vc2mFj4zNkV2s9WPSWZ4Pwbuq6FxfldI1tXJkRNFBJxnV8T3Wzxv/lCDXObveArhlMjlUw84juTFv5oQwE1Z3dPYTsytoKKeRlJLtNCic2Trjj6D97AAAAFQDLwRE+7tOTWha2rG5f036+6pYsNwAAAIBXsaU2a606eQxfwWojwiPui3eEM/1OAxOf09Ol1BhaSOSbVgjKrCN6ALfU+vE99oMSTXh1+xYlVXjm/1uyoQTZcj/Tn6r3nsnpdSy4BZHK7GmdLGGXG1SvOPRZShDlKvTKbRbaLojFMJlBWcquWexRrk2RqqtczSOeizESgpEI5AAAAIEApLlM2Hhw49hwydqKIU0yYh3gx30/fgjckwnS21n35sMnFvRIKY83PKBatr3q6t+DWP+b5BAlMDpq4yAl6wR/2x6+NnFqrCliqfXBnSOPqhejaGoGK1CWDcMBT5pOGFtce+QuhvuEn6oZQJID4pGIPL6bMBV22fKFLH38gQwS61c= spam@octavius",
            "fingerprint" => "7e:ad:2b:9c:76:31:ff:01:1f:db:e9:b2:1f:ce:35:98"}]
      end

      def starting_key_joins
        [[3030, 200]]
      end
    end  # LinkedApp

    class Empty
      attr_reader :git_remote

      def initialize(git_remote)
        @git_remote = git_remote
      end

      def apps
        []
      end

      def environments
        []
      end

      def keypairs(*args)
        []
      end
    end # Empty

    class UnlinkedApp < Empty
      def apps
        [{
            "name" => "rails232app",
            "environments" => [],
            "repository_uri" => git_remote}]
      end

      def environments
        [{
            "ssh_username" => "turkey",
            "instances" => [{
                "status" => "running",
                "id" => 27220,
                "amazon_id" => 'i-ddbbdd92',
                "role" => "solo",
                "public_hostname" => "ec2-174-129-198-124.compute-1.amazonaws.com"}],
            "name" => "giblets",
            "apps" => [],
            "instances_count" => 1,
            "stack_name" => "nginx_mongrel",
            "id" => 200,
            "framework_env" => "production",
            "app_master" => {
              "status" => "running",
              "id" => 27220,
              "amazon_id" => 'i-ddbbdd92',
              "role" => "solo",
              "public_hostname" => "ec2-174-129-198-124.compute-1.amazonaws.com"}}]
      end
    end # UnlinkedApp

 # LinkedApp

    class LinkedAppNotRunning < Empty
      def apps
        [{"name" => "rails232app",
            "environments" => [{"ssh_username" => "turkey",
                "instances" => [],
                "name" => "giblets",
                "apps" => [{"name" => "rails232app",
                    "repository_uri" => git_remote}],
                "instances_count" => 0,
                "stack_name" => "nginx_mongrel",
                "id" => 200,
                "framework_env" => "production",
                "app_master" => {}}],
            "repository_uri" => git_remote}]
      end

      def environments
        [{
            "ssh_username" => "turkey",
            "instances" => [],
            "name" => "giblets",
            "apps" => [{
                "name" => "rails232app",
                "repository_uri" => git_remote}],
            "instances_count" => 0,
            "stack_name" => "nginx_mongrel",
            "id" => 200,
           "framework_env" => "production",
           "app_master" => {}}]
      end

      def logs(env_id)
        []
      end
    end # LinkedAppNotRunning

    class LinkedAppRedMaster < LinkedApp
      def apps
        apps = super
        apps[0]["environments"][0]["instances"][0]["status"] = "error"
        apps[0]["environments"][0]["app_master"]["status"] = "error"
        apps
      end

      def environments
        envs = super
        envs[0]["instances"][0]["status"] = "error"
        envs[0]["app_master"]["status"] = "error"
        envs
      end
    end

    class OneAppManyEnvs < Empty
      def apps
        apps = [{
            "name" => "rails232app",
            "repository_uri" => git_remote
          }]

        [{"name" => "rails232app",
            "environments" => [{
                "ssh_username" => "turkey",
                "instances" => [{
                    "status" => "running",
                    "id" => 27220,
                    "amazon_id" => 'i-ddbbdd92',
                    "role" => "solo",
                    "public_hostname" => "ec2-174-129-198-124.compute-1.amazonaws.com"}],
                "name" => "giblets",
                "apps" => apps,
                "instances_count" => 1,
                "stack_name" => "nginx_mongrel",
                "id" => 200,
                "framework_env" => "production",
                "app_master" => {
                  "status" => "running",
                  "id" => 27220,
                  "amazon_id" => 'i-ddbbdd92',
                  "role" => "solo",
                  "public_hostname" => "ec2-174-129-198-124.compute-1.amazonaws.com"}
              }, {
                "ssh_username" => "ham",
                "instances" => [],
                "name" => "bakon",
                "apps" => apps,
                "instances_count" => 0,
                "stack_name" => "nginx_passenger",
                "id" => 8371,
                "app_master" => nil,
              }],
            "repository_uri" => git_remote}]
      end

      def environments
        [{
            "ssh_username" => "turkey",
            "instances" => [{
                "status" => "running",
                "id" => 27220,
                "amazon_id" => 'i-ddbbdd92',
                "role" => "solo",
                "public_hostname" => "ec2-174-129-198-124.compute-1.amazonaws.com"}],
            "name" => "giblets",
            "apps" => [{
                "name" => "rails232app",
                "repository_uri" => git_remote}],
            "instances_count" => 1,
            "stack_name" => "nginx_mongrel",
            "id" => 200,
            "framework_env" => "production",
            "app_master" => {
              "status" => "running",
              "id" => 27220,
              "amazon_id" => 'i-ddbbdd92',
              "role" => "solo",
              "public_hostname" => "ec2-174-129-198-124.compute-1.amazonaws.com"}
          }, {
            "ssh_username" => "ham",
            "instances" => [],
            "name" => "bakon",
            "apps" => [{
                "name" => "rails232app",
                "repository_uri" => git_remote}],
            "instances_count" => 0,
            "stack_name" => "nginx_passenger",
            "id" => 8371,
            "app_master" => nil,
          }, {
            "ssh_username" => "hamburger",
            "instances" => [],
            "name" => "beef",
            "apps" => [],
            "instances_count" => 0,
            "stack_name" => "nginx_passenger",
            "id" => 8372,
            "app_master" => nil,
          }]
      end
    end # OneAppTwoEnvs

    class TwoApps < Empty
      def railsapp_master
        {
          "status" => "running",
          "name" => nil,
          "role" => "solo",
          "public_hostname" => "ec2-174-129-7-113.compute-1.amazonaws.com",
          "id" => 35707,
          "amazon_id" => "i-0911f063",
        }
      end
      private :railsapp_master

      def keycollector_master
        {
          "status" => "running",
          "name" => nil,
          "role" => "solo",
          "public_hostname" => "ec2-174-129-198-124.compute-1.amazonaws.com",
          "id" => 75428,
          "amazon_id" => "i-051195b9",
        }
      end
      private :keycollector_master

      def apps
        [{
            "id" => 3202,
            "name" => "keycollector",
            "repository_uri" => "git@github.com:smerritt/keycollector.git",
            "instances_count" => 0,
            "ssh_username" => "deploy",
            "environments" => [{
                "apps" => [{
                    "name" => "keycollector",
                    "repository_uri" => "git@github.com:smerritt/keycollector.git",
                    "id" => 3202}],
                "name" => "keycollector_production",
                "app_master" => keycollector_master,
                "instances" => [keycollector_master],
                "id" => 4359,
                "framework_env" => "production",
                "stack_name" => "nginx_mongrel"}],
          }, {
            "name" => "rails232app",
            "repository_uri" => "git://github.com/smerritt/rails232app.git",
            "id" => 6125,
            "environments" => [{
                "apps" => [{
                    "name" => "rails232app",
                    "repository_uri" => "git://github.com/smerritt/rails232app.git",
                    "id" => 6125}],
                "instances_count" => 1,
                "ssh_username" => "turkey",
                "name" => "giblets",
                "app_master" => railsapp_master,
                "instances" => [railsapp_master],
                "framework_env" => "production",
                "id" => 200,
                "stack_name" => "nginx_unicorn"}],
          }]
      end

      def environments
        [{
            "id" => 200,
            "name" => "giblets",
            "ssh_username" => "turkey",
            "instances_count" => 1,
            "instances" => [railsapp_master],
            "app_master" => railsapp_master,
            "stack_name" => "nginx_unicorn",
            "apps" => [{
                "name" => "rails232app",
                "repository_uri" => "git://github.com/smerritt/rails232app.git",
                "id" => 6125}],
          }, {
            "id" => 4359,
            "framework_env" => "production",
            "name" => "keycollector_production",
            "ssh_username" => "deploy",
            "stack_name" => "nginx_mongrel",
            "instances_count" => 1,
            "instances" => [keycollector_master],
            "app_master" => keycollector_master,
            "apps" => [{
                "name" => "keycollector",
                "repository_uri" => "git@github.com:smerritt/keycollector.git",
                "id" => 3202}],
          }]
      end
    end # TwoApps

    class OneAppManySimilarlyNamedEnvs < Empty
      def apps
        apps = [{
            "name" => "rails232app",
            "repository_uri" => git_remote
          }]

        [{"name" => "rails232app",
            "environments" => [{
                "ssh_username" => "turkey",
                "instances" => [{
                    "status" => "running",
                    "id" => 27220,
                    "amazon_id" => 'i-ddbbdd92',
                    "role" => "solo",
                    "public_hostname" => "ec2-174-129-198-124.compute-1.amazonaws.com"}],
                "name" => "railsapp_production",
                "apps" => apps,
                "instances_count" => 1,
                "stack_name" => "nginx_mongrel",
                "framework_env" => "production",
                "id" => 200,
                "app_master" => {
                  "status" => "running",
                  "id" => 27220,
                  "amazon_id" => 'i-ddbbdd92',
                  "role" => "solo",
                  "public_hostname" => "ec2-174-129-198-124.compute-1.amazonaws.com",
                },
              }, {
                "ssh_username" => "ham",
                "instances" => [{
                    "public_hostname" => '127.3.2.1',
                    "status" => "running",
                    "id" => 63066,
                    "role" => "solo",
                  }],
                "name" => "railsapp_staging",
                "apps" => apps,
                "instances_count" => 1,
                "stack_name" => "nginx_passenger",
                "id" => 8371,
                "framework_env" => "production",
                "app_master" => {
                  "public_hostname" => '127.3.2.1',
                  "status" => "running",
                  "id" => 63066,
                  "role" => "solo",
                },
              }, {
                "ssh_username" => "ham",
                "instances" => [{
                    "status" => "running",
                    "id" => 59395,
                    "role" => "solo",
                    "public_hostname" => "ec2-174-129-198-124.compute-1.amazonaws.com",
                  }],
                "name" => "railsapp_staging_2",
                "apps" => apps,
                "instances_count" => 1,
                "stack_name" => "nginx_passenger",
                "id" => 8371,
                "framework_env" => "production",
                "app_master" => {
                  "public_hostname" => '127.44.55.66',
                  "status" => "running",
                  "id" => 59395,
                  "role" => "solo",
                },
              }],
            "repository_uri" => git_remote}]
      end

      def environments
        [{
            "ssh_username" => "turkey",
            "instances" => [{
                "status" => "running",
                "id" => 27220,
                "amazon_id" => 'i-ddbbdd92',
                "role" => "solo",
                "public_hostname" => "ec2-174-129-198-124.compute-1.amazonaws.com"}],
            "name" => "railsapp_production",
            "apps" => [{
                "name" => "rails232app",
                "repository_uri" => git_remote}],
            "instances_count" => 1,
            "stack_name" => "nginx_mongrel",
            "id" => 200,
            "framework_env" => "production",
            "app_master" => {
              "public_hostname" => "ec2-174-129-198-124.compute-1.amazonaws.com",
              "status" => "running",
              "id" => 27220,
              "amazon_id" => 'i-ddbbdd92',
              "role" => "solo"},
          }, {
            "ssh_username" => "ham",
            "instances" => [{
                "public_hostname" => '127.3.2.1',
                "status" => "running",
                "id" => 63066,
                "amazon_id" => 'i-09fec72a',
                "role" => "solo",
              }],
            "name" => "railsapp_staging",
            "apps" => [{
                "name" => "rails232app",
                "repository_uri" => git_remote}],
            "instances_count" => 1,
            "stack_name" => "nginx_passenger",
            "id" => 8371,
            "framework_env" => "production",
            "app_master" => {
              "public_hostname" => '127.3.2.1',
              "status" => "running",
              "id" => 63066,
              "amazon_id" => 'i-09fec72a',
              "role" => "solo",
            },
          }, {
            "ssh_username" => "chicken",
            "instances" => [{
                "public_hostname" => '127.44.55.66',
                "status" => "running",
                "id" => 59395,
                "amazon_id" => 'i-1aa1e271',
                "role" => "solo",
              }],
            "name" => "railsapp_staging_2",
            "apps" => [{
                "name" => "rails232app",
                "repository_uri" => git_remote}],
            "instances_count" => 1,
            "stack_name" => "nginx_passenger",
            "id" => 8371,
            "framework_env" => "production",
            "app_master" => {
              "public_hostname" => '127.44.55.66',
              "status" => "running",
              "id" => 59395,
              "amazon_id" => 'i-1aa1e271',
              "role" => "solo",
            },
          }]
      end

      def logs(env_id)
        [{
            "id" => env_id,
            "role" => "app_master",
            "main" => "MAIN LOG OUTPUT",
            "custom" => "CUSTOM LOG OUTPUT"
          }]
      end
    end  # OneAppManySimilarlyNamedEnvs
  end
end

run FakeAwsm.new
