#!/usr/bin/env ruby

require 'json'
require 'fileutils'
require 'git'
require 'optparse'
require 'yaml'

def copy_files(tmp_dir, server_or_device, proto_conf, options)
  release_dir = "#{tmp_dir}/#{server_or_device}"
  FileUtils.mkdir_p(release_dir)
  FileUtils.mkdir_p(File.join(release_dir, 'lib'))
  FileUtils.cp_r(File.join("lib", "protocol_generator"), File.join(release_dir, 'lib'))

  FileUtils.mkdir_p(File.join(release_dir, 'lib', 'plugins'))
  # Plugins selected in opt-in, to avoid opensourcing sensitive code
  plugin_used_in_sdk =
    case server_or_device
    when "server"
      [
        :mdi_sdk_vm_server_ruby,
        :ruby_codec_msgpack,
        :ruby_cookiesencrypt_base,
        :ruby_messages_msgpack,
        :ruby_passwdgen_redis,
        :ruby_splitter_redis,
        :ruby_sequences
      ].map {|plugin| plugin.to_s}
    when "device"
      [
        :mdi_sdk_vm_device_java,
        :morpheus3_1_codec_msgpack,
        :morpheus3_1_cookiejar_base,
        :morpheus3_1_dispatcher_base,
        :morpheus3_1_jar_compiler,
        :morpheus3_1_messages_msgpack,
        :morpheus3_1_sequences
      ].map {|plugin| plugin.to_s}
    end

  plugin_used_in_sdk.each do |plugin|
    FileUtils.cp_r(File.join("lib", "plugins", plugin), File.join(release_dir, "lib", "plugins"))
  end

  FileUtils.cp_r("doc", release_dir)
  FileUtils.cp_r("config", release_dir)
  new_conf = File.open(File.join(release_dir, "config/config.json"), 'w')
  new_conf.write(proto_conf.to_json)
  new_conf.close
  FileUtils.cp_r("protogen.rb", release_dir)
  FileUtils.cp("Gemfile", release_dir)
  FileUtils.cp("Gemfile.lock", release_dir)
  FileUtils.cp("README.md", release_dir)
  FileUtils.cp("VERSION", release_dir)

  tag = IO.readlines(File.join(release_dir, "VERSION"))[0]

  `cd #{tmp_dir}; tar cvzf #{server_or_device}_protogen_#{tag}.tar.gz #{server_or_device}; cd -` if [:both, :tar].include? options[:out_format]

  `cd #{tmp_dir}; rm -rf #{server_or_device}; cd -` unless [:both, :dir].include? options[:out_format]
end

options = {
  :out_dir => "/tmp/protogen_#{Time.now.to_i}",
  :out_format => :both,
  :local_vm => false
}
optparse = OptionParser.new do |opts|
  opts.banner = "Usage: #{__FILE__} [options]"

  opts.on("-o", "--output OUTPUT", "Output directory path") do |dir|
    options[:out_dir] = dir
  end

  opts.on("-t", "--type [TYPE]", [:tar, :dir, :both],
    "Select output format: gzipped tarball (tar), directory (dir), both (both)") do |t|
    options[:out_format] = t
  end

  opts.on("-l", "--local-vm", "Copy the release in the local vagrant machine") do |v|
    options[:local_vm] = v
  end
end

begin
  optparse.parse!
  mandatory = []
  missing = mandatory.select{ |param| options[param].nil? }
  if not missing.empty?
    puts "Missing options: #{missing.join(', ')}"
    puts optparse
    exit
  end
  raise OptionParser::InvalidOption, "#{ARGV.join(', ')} invalid options" unless ARGV.empty?
rescue OptionParser::InvalidOption, OptionParser::MissingArgument
  puts $!.to_s
  puts optparse
  exit
end


proto_conf = JSON.parse(File.open('config/config.json', 'r').read)
pg_version = proto_conf['pg_version']
if (/-dev$/.match pg_version)
  g = Git.open('.')
  pg_version = "#{pg_version}-#{g.gcommit('HEAD').sha[-10..-1]}"
  proto_conf['pg_version'] = pg_version
end
tmp_dir = options[:out_dir]

puts "Releasing #{pg_version} version in #{tmp_dir}"
copy_files(tmp_dir,"server",proto_conf,options)
copy_files(tmp_dir,"device",proto_conf,options)


# detect if yaml forward folder file exists, if yes, use it

if File.exists?('release_sdk_more_export_path.yml')

  puts ""
  puts "using more export path :"
  export_paths = YAML::load(File.open('release_sdk_more_export_path.yml'))

  export_paths.each { |k,v|

    if File.directory?("#{tmp_dir}/#{k}")
      puts "exporintg #{k} ..."

      v.each { |dir_export|
        if File.directory?("#{dir_export}")
          puts "  in folder #{dir_export}"
          FileUtils.rm_r("#{dir_export}", :secure => true)
          #FileUtils.mkdir_p("#{dir_export}")
          FileUtils.cp_r("#{tmp_dir}/#{k}/.","#{dir_export}")
        else
          puts "  Dir #{dir_export} not exists !!"
        end
      }
    end
  }


end




if options[:local_vm]
  priv_key = "-i ~/.vagrant.d/insecure_private_key"
  vm_pg_dir = "/home/vagrant/ruby-agents-sdk/web_shell/agents_generator/exts/protogen"
  puts "Copying release in the sdk vm"
  res1 = `ssh #{priv_key} -p 2222 vagrant@localhost rm -rf #{vm_pg_dir}/protocol_generator`
  puts res1 unless $?.exitstatus == 0
  res2 = `scp #{priv_key} -r -P 2222 #{tmp_dir}/server vagrant@localhost:#{vm_pg_dir}`
  puts res2 unless $?.exitstatus == 0
  res3 = `ssh #{priv_key} -p 2222 vagrant@localhost mv #{vm_pg_dir}/server #{vm_pg_dir}/protocol_generator`
  puts res3 unless $?.exitstatus == 0
end
