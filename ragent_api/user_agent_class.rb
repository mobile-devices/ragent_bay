#########################################################
# Xavier Demompion : xavier.demompion@mobile-devices.fr
# Mobile Devices 2013
#########################################################

class AgentNotFound < StandardError
end

class UserAgentClass


  def initialize(agent_name)
    @agent_name = agent_name

    # include all user code
    require_relative "#{root_path}/initial"

    # fetch module name in initial.rb (defensif)
    lines = File.readlines("#{root_path}/initial.rb")
    module_name = ""

    lines.each do |l|
      module_name = l.strip.split(' ')[1] if l.include?("module Initial_agent_")
    end

    raise "Module agent name not found" if module_name == ""

    @asset_metadata_buffer = {}

    self.singleton_class.send(:include, Object.const_get(module_name))
  end

  def agent_name
    @agent_name
  end

  def root_path
    @root_path ||= begin
      File.expand_path("#{RAGENT.agents_project_src_path}/#{agent_name}")
    end
  end

  def is_agent_has_protogen
    @is_agent_has_protogen ||= File.exist?("#{RAGENT.agents_generated_src_path}/protogen_#{agent_name}/protogen_apis.rb")
  end

  # =========


  def managed_message_channels
    @managed_message_channels ||= begin
      io_rule = self.internal_config_io_fetch_first('message')
      channels = io_rule['allowed_message_channels'] unless io_rule == nil
      CC.logger.info(channels)
      if channels.is_a? String
        channels = [channels]
      end
      channels = [] if channels == nil
      channels
    end
  end

  def queue_subscribed?(q_type)
    (internal_config_io_fetch_first(q_type) != nil)
  end

  def internal_config_io_fetch_first(q_type)
    cfg = file_internal_config_io
    return nil if cfg == nil or cfg['input_filters'] == nil or !(cfg['input_filters'].is_a? Array)

    cfg['input_filters'].each do |e|
      next unless e.is_a? Hash
      return e if e['type'] == q_type
    end
    nil
  end

  def file_internal_config_io
    @file_internal_config_io ||= begin
      config_file_path = "#{root_path}/config/internal/io.yml"
      if File.exist?(config_file_path)
        ret = YAML::load(File.open(config_file_path))
      else
        user_api.mdi.tools.log.error("NO CONFIG FILE FOUND in #{config_file_path}")
        raise "No config file found for agent '#{agent_name}'"
      end
      if ret == nil
        raise "No io configuration file for agent '#{agent_name}'"
      end
      CC.logger.info("agent io config of #{config_file_path} : #{ret}")
      ret
    rescue Exception => e
      user_api.mdi.tools.log.error("ERROR while loading io configuration")
      user_api.mdi.tools.print_ruby_exception(e)
      nil
    end
  end


  def user_config
    @file_config ||= begin
      config_file_path = "#{root_path}/config/agent.yml"
      user_api.mdi.tools.log.info("Config content: #{File.read(config_file_path)}")
      if File.exist?(config_file_path)
        ret = nil
        begin
          if RAGENT.running_env_name == 'ragent'
            ret = YAML::load(File.open(config_file_path))['mdi_cloud_env_config']
          else
            ret = YAML::load(File.open(config_file_path))['ruby_sdk__env_config']
          end
        rescue Exception => e
          raise "Can't get config gtom agent.yml file (mdi_cloud_env_config or ruby_sdk__env_config not found)"
        end
      else
        user_api.mdi.tools.log.error("NO CONFIG FILE FOUND in #{root_path}/config")
        user_api.mdi.tools.log.info("IE  #{config_file_path}")
        raise "No config file found for agent '#{agent_name}'"
      end
      CC.logger.info("agent config of #{config_file_path} : #{ret}")
      ret
    rescue Exception => e
      user_api.mdi.tools.log.error("ERROR while loading configuration")
      user_api.mdi.tools.print_ruby_exception(e)
      nil
    end
  end


  # =========

  def handle_presence(presence)

    delta_t = 0.0
    start_t = Time.now
    PUNK.start('presenceAgent')
    begin
      SDK_STATS.stats['agents'][agent_name]['received'][0] += 1
      SDK_STATS.stats['agents'][agent_name]['total_received'] += 1
      new_presence_from_device(presence)
      send_all_buffered_metadata
      delta_t = Time.now - start_t
      RUBY_AGENT_STATS.report_a_last_activity("presence_#{agent_name}", "asset: #{presence.asset}")
      PUNK.end('presenceAgent','ok','process',"AGENT:#{agent_name}TNEGA callback PRESENCE '#{presence.type}' in #{(delta_t * 1000).round}ms")
    rescue Exception => e
      empty_asset_metadata_buffer
      delta_t = Time.now - start_t
      RAGENT.api.mdi.tools.print_ruby_exception(e)
      RAGENT.api.mdi.tools.log.info("Agent '#{agent_name}' presence event that brought to this crash :\n#{presence.inspect}")
      SDK_STATS.stats['agents'][agent_name]['err_while_process'][0] += 1
      SDK_STATS.stats['agents'][agent_name]['total_error'] += 1
      RUBY_AGENT_STATS.report_an_error("presence_#{agent_name}", "#{e}")
      PUNK.end('presenceAgent','ko','process',"AGENT:#{agent_name}TNEGA callback PRESENCE fail in #{(delta_t * 1000).round}ms")
    end

    if delta_t > 3.0
      PUNK.start('presenceAgent')
      PUNK.end('presenceAgent','ko','process',"AGENT:#{agent_name}TNEGA callback PRESENCE take too much time")
    end

    RUBY_AGENT_STATS.report_new_response_time("presence|#{agent_name}", delta_t)

  end # handle_presence


  def handle_message(msg)

    delta_t = 0
    start_t = Time.now
    begin
      # Filter channel
      return if !(managed_message_channels.include? msg.channel)

      PUNK.start('msgAgent')

      msg_type = ""
      begin
        SDK_STATS.stats['agents'][agent_name]['received'][1] += 1
        SDK_STATS.stats['agents'][agent_name]['total_received'] += 1

        is_protogen = false
        if is_agent_has_protogen
          begin
            # protogen decode
            proto_object, cookies = user_api.mdi.tools.protogen.protogen_apis.decode(msg)
            msg.content = proto_object
            msg.meta['protogen_cookies'] = cookies
            msg_type = "'#{msg.class}'" if "#{msg.class}" != ""

            is_protogen = true
          rescue user_api.mdi.tools.protogen.protogen_domain::Protogen::UnknownMessageType => e
            # direct run
            RAGENT.api.mdi.tools.log.warn("Server: handle_message: unknown protogen message type: #{e.inspect}")
            raise e unless $allow_protogen_fault
          rescue => e
            RAGENT.api.mdi.tools.log.warn("Server: handle_message: protogen decode error (err=#{e.inspect})")
            raise e unless $allow_protogen_fault
          end
        else # not is_agent_has_protogen
          raise "No Protogen defined" unless $allow_non_protogen
        end

        PUNK.end('msgAgent','ok','in',"AGENT:#{agent_name}TNEGA <- MSG[#{crop_ref(msg.id,4)}] #{msg_type}")

      rescue Exception => e
        empty_asset_metadata_buffer
        RAGENT.api.mdi.tools.print_ruby_exception(e)
        RAGENT.api.mdi.tools.log.info("Agent '#{agent_name}' message event that brought to this crash :\n#{msg.inspect}")
        SDK_STATS.stats['server']['internal_error'] += 1
        SDK_STATS.stats['agents'][agent_name]['total_error'] += 1
        RUBY_AGENT_STATS.report_an_error("message_internal_#{agent_name}", "#{e}")
        PUNK.end('msgAgent','ko','in',"AGENT:#{agent_name}TNEGA <- MSG[#{crop_ref(msg.id,4)}] #{msg_type}")
        return
      end


      # process
      PUNK.start('handle', 'handling message ...')
      if is_protogen
        RAGENT.api.mdi.tools.log.info("Server: new protogen message of imei='#{msg.asset}' to agent '#{agent_name}': #{msg.content} ---------------------")
        user_api.mdi.tools.protogen.protogen_apis.process(msg)
      else

        RAGENT.api.mdi.tools.log.debug("Server: new standard message  of imei='#{msg.asset}' to agent '#{agent_name}' ---------------------")
        new_msg_from_device(msg)
      end

      send_all_buffered_metadata
      delta_t = Time.now - start_t
      RUBY_AGENT_STATS.report_a_last_activity("message_#{agent_name}_#{msg.channel}", "asset: #{msg.asset}")
      PUNK.end('handle','ok','process',"AGENT:#{agent_name}TNEGA callback MSG[#{crop_ref(msg.id,4)}] in #{(delta_t * 1000).round}ms")
    rescue => e
      empty_asset_metadata_buffer
      delta_t = Time.now - start_t
      RAGENT.api.mdi.tools.log.error("Server: /msg error on agent #{agent_name} while handle_msg")
      RAGENT.api.mdi.tools.print_ruby_exception(e)
      RAGENT.api.mdi.tools.log.info("Agent '#{agent_name}' message event that brought to this crash :\n#{msg.inspect}")
      SDK_STATS.stats['agents'][agent_name]['err_while_process'][1] += 1
      SDK_STATS.stats['agents'][agent_name]['total_error'] += 1
      RUBY_AGENT_STATS.report_an_error("message_#{agent_name}", "#{e}")
      PUNK.end('handle','ko','process',"AGENT:#{agent_name}TNEGA callback MSG[#{crop_ref(msg.id,4)}] fail in #{(delta_t * 1000).round}ms")
    end


    if delta_t > 3.0
      PUNK.start('handle')
      PUNK.end('handle','ko','process',"AGENT:#{agent_name}TNEGA callback MSG take too much time")
    end

    RUBY_AGENT_STATS.report_new_response_time("message|#{agent_name}", delta_t)

  end # handle_message



  def handle_track(track)

    delta_t = 0
    start_t = Time.now
    PUNK.start('trackAgent')
    begin
      SDK_STATS.stats['agents'][agent_name]['received'][2] += 1
      SDK_STATS.stats['agents'][agent_name]['total_received'] += 1
      new_track_from_device(track)
      send_all_buffered_metadata
      delta_t = Time.now - start_t
      RUBY_AGENT_STATS.report_a_last_activity("track_#{agent_name}", "asset: #{track.asset}")
      PUNK.end('trackAgent','ok','process',"AGENT:#{agent_name}TNEGA callback TRACK in #{(delta_t * 1000).round}ms")
    rescue Exception => e
      empty_asset_metadata_buffer
      delta_t = Time.now - start_t
      RAGENT.api.mdi.tools.print_ruby_exception(e)
      RAGENT.api.mdi.tools.log.info("Agent '#{agent_name}' track event that brought to this crash :\n#{track.inspect}")
      SDK_STATS.stats['agents'][agent_name]['err_while_process'][2] += 1
      SDK_STATS.stats['agents'][agent_name]['total_error'] += 1
      RUBY_AGENT_STATS.report_an_error("track_#{agent_name}", "#{e}")
      PUNK.end('trackAgent','ko','process',"AGENT:#{agent_name}TNEGA callback TRACK fail in #{(delta_t * 1000).round}ms")
    end


    if delta_t > 3.0
      PUNK.start('trackAgent')
      PUNK.end('trackAgent','ko','process',"AGENT:#{agent_name}TNEGA callback TRACK take too much time")
    end

    RUBY_AGENT_STATS.report_new_response_time("track|#{agent_name}", delta_t)

  end # handle_track



  def handle_order(order)
    delta_t = 0
    start_t = Time.now
    PUNK.start('orderAgent')
    begin
      SDK_STATS.stats['agents'][agent_name]['received'][3] += 1
      SDK_STATS.stats['agents'][agent_name]['total_received'] += 1
      new_order(order)
      send_all_buffered_metadata
      delta_t = Time.now - start_t
      RUBY_AGENT_STATS.report_a_last_activity("order_#{agent_name}_#{order.code}", "order params: #{order.params}")
      PUNK.end('orderAgent','ok','process',"AGENT:#{agent_name}TNEGA callback ORDER with order '#{order.code}' in #{(delta_t * 1000).round}ms")
    rescue Exception => e
      empty_asset_metadata_buffer
      delta_t = Time.now - start_t
      RAGENT.api.mdi.tools.print_ruby_exception(e)
      RAGENT.api.mdi.tools.log.info("Agent '#{agent_name}' order event that brought to this crash :\n#{order.inspect}")
      SDK_STATS.stats['agents'][agent_name]['err_while_process'][3] += 1
      SDK_STATS.stats['agents'][agent_name]['total_error'] += 1
      RUBY_AGENT_STATS.report_an_error("order_#{agent_name}", "#{e}")
      PUNK.end('orderAgent','ko','process',"AGENT:#{agent_name}TNEGA callback ORDER fail in #{(delta_t * 1000).round}ms")
    end

    if delta_t > 10.0
      PUNK.start('orderAgent')
      PUNK.end('orderAgent','ko','process',"AGENT:#{agent_name}TNEGA callback ORDER take too much time")
    end

    RUBY_AGENT_STATS.report_new_response_time("order|#{agent_name}", delta_t)

  end # handle_order



  def handle_collection(collection)

    delta_t = 0
    start_t = Time.now
    PUNK.start('collectionAgent')
    begin
      SDK_STATS.stats['agents'][agent_name]['received'][4] += 1
      SDK_STATS.stats['agents'][agent_name]['total_received'] += 1
      new_collection(collection)
      send_all_buffered_metadata
      delta_t = Time.now - start_t
      RUBY_AGENT_STATS.report_a_last_activity("collection_#{agent_name}", "collection #{collection.name}")
      PUNK.end('collectionAgent','ok','process',"AGENT:#{agent_name}TNEGA callback COLLECTION with collection '#{collection.name}' in #{(delta_t * 1000).round}ms")
    rescue Exception => e
      empty_asset_metadata_buffer
      delta_t = Time.now - start_t
      RAGENT.api.mdi.tools.print_ruby_exception(e)
      RAGENT.api.mdi.tools.log.info("Agent '#{agent_name}' collection event that brought to this crash :\n#{collection.inspect}")
      SDK_STATS.stats['agents'][agent_name]['err_while_process'][4] += 1
      SDK_STATS.stats['agents'][agent_name]['total_error'] += 1
      RUBY_AGENT_STATS.report_an_error("collection_#{agent_name}", "#{e}")
      PUNK.end('collectionAgent','ko','process',"AGENT:#{agent_name}TNEGA callback COLLECTION fail in #{(delta_t * 1000).round}ms")
    end

    if delta_t > 3.0
      PUNK.start('collectionAgent')
      PUNK.end('collectionAgent','ko','process',"AGENT:#{agent_name}TNEGA callback COLLECTION take too much time")
    end

    RUBY_AGENT_STATS.report_new_response_time("collection|#{agent_name}", delta_t)

  end # handle_collection



  def handle_asset_config(asset_config)
    delta_t = 0
    start_t = Time.now
    PUNK.start('assetConfigAgent')
    begin
      SDK_STATS.stats['agents'][agent_name]['received'][6] += 1
      SDK_STATS.stats['agents'][agent_name]['total_received'] += 1
      new_asset_config(asset_config)
      send_all_buffered_metadata
      delta_t = Time.now - start_t
      RUBY_AGENT_STATS.report_a_last_activity("asset_config_#{agent_name}_#{asset_config.asset}", "asset_config{asset_config.asset}")
      PUNK.end('assetConfigAgent','ok','process',"AGENT:#{agent_name}TNEGA callback ASSET CONFIG with asset_config '#{asset_config.asset}' in #{(delta_t * 1000).round}ms")
    rescue Exception => e
      empty_asset_metadata_buffer
      delta_t = Time.now - start_t
      RAGENT.api.mdi.tools.print_ruby_exception(e)
      RAGENT.api.mdi.tools.log.info("Agent '#{agent_name}' asset_config event that brought to this crash :\n#{asset_config.inspect}")
      SDK_STATS.stats['agents'][agent_name]['err_while_process'][6] += 1
      SDK_STATS.stats['agents'][agent_name]['total_error'] += 1
      RUBY_AGENT_STATS.report_an_error("asset_config_#{agent_name}", "#{e}")
      PUNK.end('assetConfigAgent','ko','process',"AGENT:#{agent_name}TNEGA callback ASSET CONFIG fail in #{(delta_t * 1000).round}ms")
    end

    if delta_t > 10.0
      PUNK.start('assetConfigAgent')
      PUNK.end('assetConfigAgent','ko','process',"AGENT:#{agent_name}TNEGA callback ASSET CONFIG take too much time")
    end

    RUBY_AGENT_STATS.report_new_response_time("asset_config|#{agent_name}", delta_t)

  end # handle_order

  def handle_other_queue(params, queue)
    delta_t = 0
    start_t = Time.now
    PUNK.start('otherqueueAgent')
    begin
      SDK_STATS.stats['agents'][agent_name]['received'][4] += 1
      SDK_STATS.stats['agents'][agent_name]['total_received'] += 1
      new_message_from_queue(params, queue)
      send_all_buffered_metadata
      delta_t = Time.now - start_t
      RUBY_AGENT_STATS.report_a_last_activity("queue_#{queue}_#{agent_name}", "queue #{queue}")
      PUNK.end('otherqueueAgent','ok','process',"AGENT:#{agent_name}TNEGA callback OTHER_QUEUE with queue #{queue} in #{(delta_t * 1000).round}ms")
    rescue Exception => e
      empty_asset_metadata_buffer
      delta_t = Time.now - start_t
      RAGENT.api.mdi.tools.print_ruby_exception(e)
      RAGENT.api.mdi.tools.log.info("Agent '#{agent_name}'  queue #{queue} event that brought to this crash :\n#{params.inspect}")
      SDK_STATS.stats['agents'][agent_name]['err_while_process'][4] += 1
      SDK_STATS.stats['agents'][agent_name]['total_error'] += 1
      RUBY_AGENT_STATS.report_an_error("queue_#{queue}_#{agent_name}", "#{e}")
      PUNK.end('otherqueueAgent','ko','process',"AGENT:#{agent_name}TNEGA callback OTHER_QUEUE failed in #{(delta_t * 1000).round}ms")
    end

    if delta_t > 3.0
      PUNK.start('otherqueueAgent')
      PUNK.end('otherqueueAgent','ko','process',"AGENT:#{agent_name}TNEGA callback OTHER_QUEUE took too much time")
    end

    RUBY_AGENT_STATS.report_new_response_time("queue_#{queue}_#{agent_name}", delta_t)
  end # handle_other_queue

  def buffer_set_asset_metadatum(account, imei, asset_metadatum)
    @asset_metadata_buffer[account] ||= {}
    @asset_metadata_buffer[account][imei] ||= []
    metadata = @asset_metadata_buffer[account][imei]
    idx = metadata.index { |x| x[:name] == asset_metadatum[:name] }
    if idx.nil?
      metadata << asset_metadatum.clone
    else
      # update existing buffered metadata
      metadata[idx][:type] = asset_metadatum[:type]
      metadata[idx][:value] = asset_metadatum[:value]
    end
  end

  def send_all_buffered_metadata
    metadata_buffer = @asset_metadata_buffer.clone
    @asset_metadata_buffer.clear

    metadata_buffer.each do |account,imei_hash|
      imei_hash.each do |imei, asset_metadata|
        send_asset_metadata(account, imei, asset_metadata)
      end
    end
  end

  # Set the specific metadata of an asset
  # @return true if success, false if failed
  # @param [String] account asset's account
  # @param [String] imei asset's imei
  # @param [Array] asset_metadata an array of metadatum (AssetMetadatumClass)
  def send_asset_metadata(account, imei, asset_metadata)
    PUNK.start('sendassetmetadata','send asset metadata...')

    begin
      CC::RagentHttpApiV3.request_http_cloud_api_put(account, "/assets/#{imei}/metadata_bulk_update.json", asset_metadata.to_json)
    rescue Exception => e
      user_api.mdi.tools.log.error("Error on send asset metadata")
      user_api.mdi.tools.print_ruby_exception(e)
      PUNK.end('sendassetmetadata','ko','out',"SERVER <- SERVER ASSET_METADATA")
      return false
    end

    PUNK.end('sendassetmetadata','ok','out',"SERVER <- SERVER ASSET_METADATA")
    true
  end

  def empty_asset_metadata_buffer
    @asset_metadata_buffer.clear
  end
end
