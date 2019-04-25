
module ProtocolGenerator
  module Generator
    class Morpheus31JarCompiler < GeneratorPlugin

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

        jar_file = File.join(dir,"#{protocol_set.config.get(:java, :package_name)}.jar")

        jar jar_file => :compile do |t|
          t.files << JarFiles[dir, "**/*.class"]
          # t.main_class = 'org.whathaveyou.Main'
          t.manifest = {:version => '1.0.0'}
        end

        javac :compile => dir do |t|
          t.src << Sources[dir, "**/*.java"]
          t.classpath << protocol_set.config.get(:java, :mdi_jar_path)
          t.dest = dir
        end

        directory dir

        Rake.application[jar_file].invoke

        FileUtils.rm(File.join(dir, "#{protocol_set.config.get(:java, :package_name)}.jar"), :force => :true) unless protocol_set.config.get(:java, :keep_jar)
        if protocol_set.config.get(:java, :keep_source)
          FileUtils.mv(File.join(dir, java_dirs.first), protocol_set.config.get(:java, :keep_source_path), :secure => :true, :force => :true) if protocol_set.config.get(:java, :keep_source_path)
        else
          FileUtils.rm_r(File.join(dir, java_dirs.first), :secure => :true, :force => :true)
        end
      end

      @dependencies = []
      @priority = -5
      init
    end
  end # Generator
end # ProtocolGenerator
