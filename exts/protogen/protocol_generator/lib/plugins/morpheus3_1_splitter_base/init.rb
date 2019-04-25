module ProtocolGenerator
  module Generator
    class Morpheus31SplitterBase < GeneratorPlugin
      def self.run(protocol_set)
        if protocol_set.protocols.size > 1
          raise "Can not generate device code with more than one protocol_version"
        end
        protocol = protocol_set.protocols.first
        java_path = protocol_set.config.get(:java, :package_name).split('.')
        dir = protocol_set.config.get(:java, :temp_output_path)
        FileUtils.mkdir_p(dir) if !File.directory?(dir)
        FileUtils.mkdir_p(File.join(dir,java_path))
        Utils.render(File.join(@templates_dir,'Splitter.java.erb'), File.join(dir,java_path,'Splitter.java'), binding)
      end

      @dependencies = []
      init
    end
  end # Generator
end # ProtocolGenerator