module ProtocolGenerator
  module Generator
    class Morpheus31MessagesMsgPack < GeneratorPlugin
      def self.nullvalue(type, is_array)
        if is_array
          'null'
        else
          case type
          when 'int' then '0'
          when 'float' then '0.0f'
          when 'bool' then false
          else
            'null'
          end
        end
      end
      def self.run(protocol_set)
        if protocol_set.protocols.size > 1
          raise "Can not generate device code with more than one protocol_version"
        end
        protocol = protocol_set.protocols.first
        plugin = self
        java_path = protocol_set.config.get(:java, :package_name).split('.')
        dir = protocol_set.config.get(:java, :temp_output_path)
        FileUtils.mkdir_p(File.join(dir,java_path))
        Utils.render(File.join(@templates_dir, 'MDIMessages.java.erb'), File.join(dir ,java_path,"MDIMessages.java"),binding)
        Utils.render(File.join(@templates_dir, 'ProtogenMessages.java.erb'), File.join(dir,java_path,"ProtogenMessages.java"),binding)
      end

      @dependencies = []
      @priority = 10
      init
    end
  end # Generator
end # ProtocolGenerator
