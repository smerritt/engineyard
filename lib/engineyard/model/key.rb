module EY
  module Model
    class Key < ApiStruct.new(:id, :name, :public_key, :fingerprint)

      def find_locally(key_dir = File.join(ENV['HOME'], ".ssh"))
        Dir.chdir(key_dir) do
          Dir.glob["*.pub"].find do |public_key_file|
            File.read(public_key_file).strip == public_key.strip
          end
        end
      end

    end
  end
end
