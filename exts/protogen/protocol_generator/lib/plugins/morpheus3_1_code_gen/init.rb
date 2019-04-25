
module ProtocolGenerator
  module Generator
    class Morpheus31CodeGenerator < GeneratorPlugin

      class << self
        include Rake::DSL
      end

      def self.run(protocol_set)
        if protocol_set.protocols.size > 1
          raise "Can not generate device code with more than one protocol_version"
        end
        protocol = protocol_set.protocols.first
        java_dirs = protocol_set.config.get(:java, :package_name).split('.')
        dir = protocol_set.config.get(:java, :temp_output_path)
        java_path = File.join(dir,java_dirs)
        FileUtils.mv(File.join(dir, java_dirs.first), protocol_set.config.get(:java, :keep_source_path), :secure => :true, :force => :true) if protocol_set.config.get(:java, :keep_source_path)
      end

      @dependencies = []
      @priority = -5
      init
    end
  end # Generator
end # ProtocolGenerator
