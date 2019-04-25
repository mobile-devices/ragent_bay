
module ProtocolGenerator
  module Generator
    class MDIRubySDKVM < GeneratorPlugin
      def self.run(protocol_set)
        if protocol_set.protocols.size > 1
          raise "Can not generate device code with more than one protocol_version"
        end
        protocol = protocol_set.protocols.first
        tmp_device_directory = protocol_set.config.get(:java, :temp_output_path)
        output_directory = protocol_set.config.get(:java, :output_path)

        YARD::Tags::Library.define_tag "ProtocolGenerator version", :protogen_version
        YARD::Tags::Library.define_tag "Protocol version", :protocol_version

        # No doc generated for the java APIs. It's up to the end developper to do it on his own.
        # Utils.render(File.join(@templates_dir, '.doxygen.erb'), File.join(device_directory, ".doxygen"))
        # puts `cd #{device_directory}; doxygen .doxygen; cd -`

        FileUtils.mkdir_p(output_directory)
        FileUtils.mv(Dir.glob(File.join(tmp_device_directory, "*")), output_directory, :force => true)
        # FileUtils.mv(Dir.glob(File.join(device_directory, "doc")), output_directory, :force => true)
        FileUtils.rm_r(tmp_device_directory, :secure => true)
      end

      @dependencies = [
        :morpheus3_1_codec_msgpack,
        :morpheus3_1_cookiejar_base,
        :morpheus3_1_dispatcher_base,
        :morpheus3_1_sequences,
        :morpheus3_1_splitter_base,
        :morpheus3_1_jar_compiler
      ]
      @priority = -10
      init
    end
  end # Generator
end # ProtocolGenerator
