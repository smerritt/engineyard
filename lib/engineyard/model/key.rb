module EY
  module Model
    class Key < ApiStruct.new(:id, :name, :public_key, :fingerprint, :api)

      def environments
        @environments ||=
          begin
            raw_envs = api.request("/keypairs/#{id}/environments")["environments"]
            Collection::Environments[*Environment.from_array(raw_envs, :api => api)]
          end
      end

    end
  end
end
