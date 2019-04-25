module ProtocolGenerator
  module Generator
    class Morpheus31CookieJarBase < GeneratorPlugin
      def self.run(protocol_set)
        if protocol_set.protocols.size > 1
          raise "Can not generate device code with more than one protocol_version"
        end
        protocol = protocol_set.protocols.first
        java_path = protocol_set.config.get(:java, :package_name).split('.')
        dir = protocol_set.config.get(:java, :temp_output_path)
        FileUtils.mkdir_p(dir) if !File.directory?(dir)
        FileUtils.mkdir_p(File.join(dir,java_path))
        # CookieJar
        Utils.render(File.join(@templates_dir,'CookieJar.java.erb'), File.join(dir,java_path,'CookieJar.java'), binding) if protocol.has_cookies?
      end

      @dependencies = []
      init
    end
  end # Generator
end # ProtocolGenerator
