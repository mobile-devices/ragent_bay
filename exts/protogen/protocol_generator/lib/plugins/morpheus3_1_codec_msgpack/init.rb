module ProtocolGenerator
  module Generator
    class Morpheus31CodecMsgpack < GeneratorPlugin
      def self.run(protocol_set)
        if protocol_set.protocols.size > 1
          raise "Can not generate device code with more than one protocol_version"
        end
        protocol = protocol_set.protocols.first
        java_path = protocol_set.config.get(:java, :package_name).split('.')
        dir = protocol_set.config.get(:java, :temp_output_path)
        FileUtils.mkdir_p(dir) if !File.directory?(dir)
        FileUtils.mkdir_p(File.join(dir,java_path))
        Utils.render(File.join(@templates_dir, 'Codec.java.erb'),
          File.join(dir, java_path,'Codec.java'),
          binding)
      end

      @dependencies = [:morpheus3_1_messages_msgpack]
      @priority = 9
      init
    end
  end # Generator
end # ProtocolGenerator
