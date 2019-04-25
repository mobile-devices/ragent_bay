module ProtocolGenerator
  module Generator
    class Morpheus31DispatcherBase < GeneratorPlugin
      def self.run(protocol_set)
        if protocol_set.protocols.size > 1
          raise "Can not generate device code with more than one protocol_version"
        end
        protocol = protocol_set.protocols.first
        java_path = protocol_set.config.get(:java, :package_name).split('.')
        dir = protocol_set.config.get(:java, :temp_output_path)
        FileUtils.mkdir_p(dir) if !File.directory?(dir)
        FileUtils.mkdir_p(File.join(dir,java_path))
        Utils.render(File.join(@templates_dir,'Dispatcher.java.erb'), File.join(dir,java_path,'Dispatcher.java'), binding)
        Utils.render(File.join(@templates_dir,'SequenceController.java.erb'), File.join(dir,java_path,'ISequenceController.java'), binding)
        if protocol.has_callback?(:out_of_sequence_callback)
          Utils.render(File.join(@templates_dir,'Sequence.java.erb'), File.join(dir,java_path,'Sequence.java'), binding)
          Utils.render(File.join(@templates_dir,'Shot.java.erb'), File.join(dir,java_path,'Shot.java'), binding)
        end
        protocol.sequences.each do |seq|
          Utils.render(File.join(@templates_dir, 'Controller.java.erb'), File.join(dir, java_path,"I#{seq.name}Controller.java"), binding)
        end
      end

      @dependencies = []
      init
    end
  end # Generator
end # ProtocolGenerator