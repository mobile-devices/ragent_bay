#########################################################
# Xavier Demompion : xavier.demompion@mobile-devices.fr
# Mobile Devices 2013
#########################################################

module RagentIncomingMessage


  def self.valid_params(params)
    if params['meta'] == nil or params['payload'] == nil
      begin
        raise "RagentIncomingMessage: bad incoming params structure: #{params}"
      rescue Exception => e
        PUNK.start('valid')
        RAGENT.api.mdi.tools.print_ruby_exception(e)
        RAGENT.api.mdi.tools.log.info("Ragent error parse params :\n#{params}")
        RUBY_AGENT_STATS.report_an_error("ragent params parse fail", "#{e}")
        SDK_STATS.stats['server']['internal_error'] += 1
        PUNK.end('valid','ko','in',"SERVER <- ?? : missing params fail")
        return false
      end
    end
    true
  end

  # "As others have pointed out, clone will do it. Be aware that clone of a hash makes a shallow copy."
  def self.deep_copy(o)
    Marshal.load(Marshal.dump(o))
  end


  def self.handle_presence(params)

    # valid input
    if RIM.valid_params(params)
      account = params['meta']['account']
    else
      return
    end

    PUNK.start('new')
    RAGENT.api.mdi.tools.log.debug("\n\n\n\nServer: new incoming presence:\n#{params}")
    PUNK.end('new','ok','in',"SERVER <- PRESENCE : receive new presence")
    SDK_STATS.stats['server']['received'][0] += 1



    # forward to each agent
    RAGENT.user_class_presence_subscriber.get_subscribers.each do |user_agent_class|
      io_rule = user_agent_class.internal_config_io_fetch_first('presence')
      next if io_rule == nil
      next unless io_rule['allowed_accounts'].include? account

      begin
        PUNK.start('damned')
        # set associated api as current sdk_api
        env = {
          'account' => account,
          'agent_name' => user_agent_class.agent_name
        }
        apis = USER_API_FACTORY.gen_user_api(user_agent_class, env)

        # create Presence object
        if RAGENT.user_class_subscriber.size == 1
          presence = apis.mdi.dialog.create_new_presence(params)
        else
          presence = apis.mdi.dialog.create_new_presence(RIM.deep_copy(params))
        end

        # set user api
        apis.initial_event_content = presence.clone
        set_current_user_api(apis)

        # check route loop
        looped = presence.meta['event_route'].select {|route| route["name"] == user_agent_class.agent_name }.first
        if looped != nil
          PUNK.start('loopdrop')
          RAGENT.api.mdi.tools.log.warn("Loop detected. Dropping incoming presence #{presence.id}")
          PUNK.end('loopdrop','warn','notif',"Loop detected. AGENT:#{user_agent_class.agent_name}TNEGA drop incoming presence #{presence.id}")
          next
        end

        PUNK.start('new')
        RAGENT.api.mdi.tools.log.debug("#{user_agent_class.agent_name}: new incoming presence:\n#{presence.inspect}")
        PUNK.end('new','ok','in',"AGENT:#{user_agent_class.agent_name}TNEGA <- PRESENCE [#{presence.type}]")


        # process it, should never fail, but if its happen we will have a wrong error on parse fail but no deadlock
        user_agent_class.handle_presence(presence)

      rescue Exception => e
        RAGENT.api.mdi.tools.print_ruby_exception(e)
        RAGENT.api.mdi.tools.log.info("Ragent error parse presence :\n#{params}")
        RUBY_AGENT_STATS.report_an_error("ragent presence parse fail", "#{e}")
        SDK_STATS.stats['server']['err_parse'][0] += 1
        SDK_STATS.stats['server']['internal_error'] += 1
        PUNK.end('damned','ko','in',"SERVER <- PRESENCE : parse params fail")
      ensure
        PUNK.drop('damned')
        release_current_user_api
      end

    end # each user_agent_class

  end # handle_presence



  def self.handle_message(params)

    # valid input
    if valid_params(params)
      account = params['meta']['account']
      channel = params['payload']['channel']
    else
      return
    end

    # drop if unmanaged
    return unless RAGENT.supported_message_channels.include? channel || RAGENT.supported_message_channels.include?('ALL_CHANNELS')

    PUNK.start('new')
    RAGENT.api.mdi.tools.log.debug("\n\n\n\nServer: new incoming message:\n#{params}")
    SDK_STATS.stats['server']['received'][1] += 1

    # vm-mode jBinaryGate: ack the message
    if RAGENT.running_env_name == 'sdk-vm'
      PUNK.start('ackmsgvm')
      # create Message object
      begin
        ragent_msg = RAGENT.api.mdi.dialog.create_new_message(RIM.deep_copy(params))
        if ragent_msg.channel == 0
          RAGENT.api.mdi.tools.log.warn("The message is on channel 0, we drop it !")
          PUNK.drop('new')
          return
        end
      rescue Exception => e
        RAGENT.api.mdi.tools.print_ruby_exception(e)
        SDK_STATS.stats['server']['err_parse'][1] += 1
        SDK_STATS.stats['server']['internal_error'] += 1
        PUNK.end('ackmsgvm','ko','in',"SERVER -> ACK : ack to device fail: invalid message")
        return
      end

      begin
        RAGENT.api.mdi.tools.log.debug("Server: push_ack_to_device: creating new ack message")
        tmp_id_from_device = ragent_msg.id
        parent_id = CC.indigen_next_id
        ragent_msg.id = parent_id
        channel_str = ragent_msg.channel
        channel_int = RAGENT.map_supported_message_channels[channel_str]
        RAGENT.api.mdi.tools.log.debug("Server: push_ack_to_device: for channel #{channel_str} using number #{channel_int}")

        ack_map = Hash.new
        ack_map['channel'] =  channel_int
        ack_map['channelStr'] = channel_str
        ack_map['tmpId'] = tmp_id_from_device
        ack_map['msgId'] = parent_id
        msgAck = ragent_msg.clone
        msgAck.content = ack_map.to_json
        msgAck.type = 'ackmessage'

        RAGENT.api.mdi.tools.log.info("Server: push_ack_to_device: adding Ack message with tmpId=#{ack_map['tmpId']} and msgId=#{ack_map['msgId']}")

        push_something_to_device(msgAck.to_hash)

        TestsHelper.id_generated(parent_id, tmp_id_from_device)

        SDK_STATS.stats['server']['total_ack_queued'] += 1
        PUNK.end('ackmsgvm','ok','in',"SERVER -> ACK[#{parent_id}] of MSG[#{tmp_id_from_device}]")
      rescue Exception => e
        RAGENT.api.mdi.tools.log.error("Server: push_ack_to_device error with payload = \n#{ragent_msg}")
        RAGENT.api.mdi.tools.print_ruby_exception(e)
        PUNK.end('ackmsgvm','ko','in',"SERVER -> ACK : ack to device fail")
        return
      end
    else
      # create Message object
      begin
        if RAGENT.user_class_subscriber.size == 1
          ragent_msg = RAGENT.api.mdi.dialog.create_new_message(params)
        else
          ragent_msg = RAGENT.api.mdi.dialog.create_new_message(RIM.deep_copy(params))
        end
      rescue Exception => e
        RAGENT.api.mdi.tools.print_ruby_exception(e)
        RAGENT.api.mdi.tools.log.info("Ragent error parse message :\n#{params}")
        RUBY_AGENT_STATS.report_an_error("ragent track parse fail", "#{e}")
        RAGENT.api.mdi.tools.log.info("error on message :\n#{msg.inspect}")
        SDK_STATS.stats['server']['err_parse'][1] += 1
        SDK_STATS.stats['server']['internal_error'] += 1
        return
      end
    end # end vm mode



    PUNK.end('new','ok','in',"SERVER <- MSG : receive new message")

    # forward to each agent
    RAGENT.user_class_message_subscriber.get_subscribers.each do |user_agent_class|
      io_rule = user_agent_class.internal_config_io_fetch_first('message')
      next if io_rule == nil
      next unless io_rule['allowed_accounts'].include? account


      if io_rule['allowed_message_channels'].include? channel || io_rule['allowed_message_channels'].include?('ALL_CHANNELS')

        begin
          PUNK.start('damned')
          env = {
            'account' => account,
            'agent_name' => user_agent_class.agent_name
          }

          # set associated api as current sdk_api
          apis = USER_API_FACTORY.gen_user_api(user_agent_class, env)
          apis.initial_event_content = ragent_msg.clone
          set_current_user_api(apis)


          # check route loop
          looped = ragent_msg.meta['event_route'].select {|route| route["name"] == user_agent_class.agent_name }.first
          if looped != nil
            PUNK.start('loopdrop')
            RAGENT.api.mdi.tools.log.warn("Loop detected. Dropping incoming message #{ragent_msg.id}")
            PUNK.end('loopdrop','warn','notif',"Loop detected. AGENT:#{user_agent_class.agent_name}TNEGA drop incoming message #{message.id}")
            next
          end

          PUNK.start('new')
          RAGENT.api.mdi.tools.log.debug("#{user_agent_class.agent_name}: new incoming message:\n#{ragent_msg.inspect}")
          PUNK.end('new','ok','in',"AGENT:#{user_agent_class.agent_name}TNEGA <- MESSAGE [#{ragent_msg.channel}]")

          # process it, should never fail, but if its happen we will have a wrong error on parse fail but no deadlock
          user_agent_class.handle_message(ragent_msg)

        rescue Exception => e
          RAGENT.api.mdi.tools.print_ruby_exception(e)
          RAGENT.api.mdi.tools.log.info("Ragent error init api env :\n#{env}")
          RUBY_AGENT_STATS.report_an_error("ragent message init env", "#{e}")
          SDK_STATS.stats['server']['err_parse'][1] += 1
          SDK_STATS.stats['server']['internal_error'] += 1
          PUNK.end('damned','ko','in',"SERVER <- MESSAGE : bad init apis set_current_user_api")
        ensure
          PUNK.drop('damned')
          release_current_user_api
        end

      end
    end # each user_agent_class


  end # handle_message


  def self.handle_track(params)

    RAGENT.api.mdi.tools.log.debug("new track")

    # valid input
    if valid_params(params)
      account = params['meta']['account']
    else
      return
    end

    PUNK.start('new')
    RAGENT.api.mdi.tools.log.debug("\n\n\n\nServer: new incoming track:\n#{params}")
    PUNK.end('new', 'ok', 'in', "SERVER <- TRACK : receive new track")
    SDK_STATS.stats['server']['received'][2] += 1

    # forward to each agent
    (RAGENT.user_class_track_subscriber.get_subscribers + RAGENT.user_class_track_cached_subscriber.get_subscribers).each do |user_agent_class|
      io_rule = user_agent_class.internal_config_io_fetch_first('track')
      next if io_rule == nil
      next unless io_rule['allowed_accounts'].include? account

      begin
        PUNK.start('damned')
        env = {
          'account' => account,
          'agent_name' => user_agent_class.agent_name
        }

        apis = USER_API_FACTORY.gen_user_api(user_agent_class, env)

        # create Track object
        if RAGENT.user_class_subscriber.size == 1
          track = apis.mdi.dialog.create_new_track(params)
        else
          track = apis.mdi.dialog.create_new_track(RIM.deep_copy(params))
        end

        # set associated api as current sdk_api
        apis.initial_event_content = track.clone
        set_current_user_api(apis)

        RAGENT.api.mdi.tools.log.debug("track has fresh values: #{track.meta['include_fresh_track_field']}")

        # check route loop
        looped = track.meta['event_route'].select {|route| route["name"] == user_agent_class.agent_name }.first
        if looped != nil and !(track.meta['include_fresh_track_field'])
          PUNK.start('loopdrop')
          RAGENT.api.mdi.tools.log.warn("Loop detected. Dropping incoming track #{track.id}")
          PUNK.end('loopdrop','warn','notif',"Loop detected. AGENT:#{user_agent_class.agent_name}TNEGA drop incoming track #{track.id}")
          next
        end

        # In case of field data is empty, a user might want just use the position, but if the event_route is not empty, this mean that it already received it, so we drop it
        if track.fields_data.size == 0 and track.meta['event_route'].is_a? Array and track.meta['event_route'].size > 1
          PUNK.start('emptyDrop')
          RAGENT.api.mdi.tools.log.warn("Raw track part already received. Dropping incoming track #{track.id}")
          PUNK.end('emptyDrop','warn','notif', "Enhanced track without fields. AGENT:#{user_agent_class.agent_name}TNEGA drop incoming track #{track.id}")
          next
        end

        PUNK.start('new')
        # injected cache (vm mode)
        track = TrackCache.inject_cache(track) if RAGENT.running_env_name == 'sdk-vm' and io_rule['track_fields_cached'] != nil and io_rule['track_fields_cached'] == true
        RAGENT.api.mdi.tools.log.debug("#{user_agent_class.agent_name}: new incoming track:\n#{track.inspect}")
        str_field_cached = " (#{track.meta['fields_cached'].size / 2})" if track.meta['fields_cached'].is_a? Hash
        PUNK.end('new','ok','in',"AGENT:#{user_agent_class.agent_name}TNEGA <- TRACK [#{track.fields_data.size} fields#{str_field_cached}]")


        # process it, should never fail, but if its happen we will have a wrong error on parse fail but no deadlock
        user_agent_class.handle_track(track)

      rescue Exception => e
        RAGENT.api.mdi.tools.print_ruby_exception(e)
        RAGENT.api.mdi.tools.log.info("Ragent error parse track :\n#{params}")
        RUBY_AGENT_STATS.report_an_error("ragent track parse fail", "#{e}")
        SDK_STATS.stats['server']['err_parse'][2] += 1
        SDK_STATS.stats['server']['internal_error'] += 1
        PUNK.end('damned','ko','in',"SERVER <- TRACK : parse params fail")
      ensure
        PUNK.drop('damned')
        release_current_user_api
      end

    end # each user_agent_class


  end # handle_track


  def self.handle_order(params)

    RAGENT.api.mdi.tools.log.debug("new order")

    # filter
    assigned_agent = RAGENT.get_agent_from_name(params['agent'])

    if assigned_agent == nil
      PUNK.start('damned')
      PUNK.end('damned','ko','in',"SERVER <- ORDER : agent not found")
    end

    PUNK.start('new')
    RAGENT.api.mdi.tools.log.debug("\n\n\n\nServer: new incoming order:\n#{params}")
    SDK_STATS.stats['server']['received'][3] += 1
    PUNK.end('new','ok','in',"SERVER <- ORDER for agent '#{assigned_agent.agent_name}'")

    begin
      PUNK.start('damned')
      env = {
        'env' => 'order',
        'agent_name' => assigned_agent.agent_name
      }
      apis = USER_API_FACTORY.gen_user_api(assigned_agent, env)

      # create Order object
      order = apis.mdi.dialog.create_new_order(params)

      # set associated api as current sdk_api
      apis.initial_event_content = order.clone
      set_current_user_api(apis)

      # No need to check route loop (i guess)

      PUNK.start('new')
      RAGENT.api.mdi.tools.log.debug("#{assigned_agent.agent_name}: new incoming order:#{order.inspect}")
      PUNK.end('new','ok','in',"AGENT:#{assigned_agent.agent_name}TNEGA <- ORDER [#{order.code}]")

      # process it, should never fail, but if its happen we will have a wrong error on parse fail but no deadlock
      assigned_agent.handle_order(order)

    rescue AgentNotFound => e
      RAGENT.api.mdi.tools.print_ruby_exception(e)
      response.body = 'service unavailable'
      SDK_STATS.stats['server']['remote_call_unused'] += 1
      SDK_STATS.stats['server']['total_error'] += 1
      PUNK.end('damned','ko','in',"SERVER <- ORDER : agent not found")
    rescue Exception => e
      RAGENT.api.mdi.tools.print_ruby_exception(e)
      RAGENT.api.mdi.tools.log.info("Ragent error parse order :\n#{params}")
      RUBY_AGENT_STATS.report_an_error("ragent order parse fail", "#{e}")
      SDK_STATS.stats['server']['err_parse'][3] += 1
      SDK_STATS.stats['server']['internal_error'] += 1
      PUNK.end('damned','ko','in',"SERVER <- ORDER : parse params fail")
    ensure
      PUNK.drop('damned')
      release_current_user_api
    end

  end # handle_order

  def self.handle_collection(params)
    #RAGENT.api.mdi.tools.log.info("new collection #{params}")

    # valid input
    if valid_params(params)
      account = params['meta']['account']
      name = params['payload']['name']
    else
      return
    end

    PUNK.start('new')
    RAGENT.api.mdi.tools.log.debug("\n\n\n\nServer: new incoming collection:\n#{params}")
    PUNK.end('new','ok','in',"SERVER <- COLLECTION : receive new collection")
    SDK_STATS.stats['server']['received'][4] += 1


    # forward to each agent
    RAGENT.user_class_collection_subscriber.get_subscribers.each do |user_agent_class|
      io_rule = user_agent_class.internal_config_io_fetch_first('collection')
      next if io_rule == nil
      next unless io_rule['allowed_accounts'].include? account
      next unless ((io_rule['allowed_collection_definition_names'].include? name) or (io_rule['allowed_collection_definition_names'].include?('ALL_COLLECTIONS')))

      begin
        PUNK.start('damned')
        env = {
          'account' => account,
          'agent_name' => user_agent_class.agent_name
        }

        apis = USER_API_FACTORY.gen_user_api(user_agent_class, env)

        # create collection object
        if RAGENT.user_class_subscriber.size == 1
          collection = apis.mdi.dialog.create_new_collection(params)
        else
          collection = apis.mdi.dialog.create_new_collection(RIM.deep_copy(params))
        end


        # set associated api as current sdk_api
        apis.initial_event_content = collection.clone
        set_current_user_api(apis)

        # check route loop
        looped = collection.meta['event_route'].select {|route| route["name"] == user_agent_class.agent_name }.first
        if looped != nil
          PUNK.start('loopdrop')
          RAGENT.api.mdi.tools.log.warn("Loop detected. Dropping incoming collection #{collection.id}")
          PUNK.end('loopdrop','warn','notif',"Loop detected. AGENT:#{user_agent_class.agent_name}TNEGA drop incoming collection #{collection.id}")
          next
        end

        PUNK.start('new')
        RAGENT.api.mdi.tools.log.debug("#{user_agent_class.agent_name}: new incoming collection:\n#{collection.inspect}")
        PUNK.end('new','ok','in',"AGENT:#{user_agent_class.agent_name}TNEGA <- COLLECTION [#{collection.name}]")

        # process it, should never fail, but if its happen we will have a wrong error on parse fail but no deadlock
        user_agent_class.handle_collection(collection)
      rescue Exception => e
        RAGENT.api.mdi.tools.print_ruby_exception(e)
        RAGENT.api.mdi.tools.log.info("Ragent error parse collection :\n#{params}")
        RUBY_AGENT_STATS.report_an_error("ragent collection parse fail", "#{e}")
        SDK_STATS.stats['server']['err_parse'][4] += 1
        SDK_STATS.stats['server']['internal_error'] += 1
        PUNK.end('damned','ko','in',"SERVER <- COLLECTION : parse params fail")
      ensure
        PUNK.drop('damned')
        release_current_user_api
      end

    end # each user_agent_class

  end # handle_collection

  def self.handle_poke(params)

    # valid input
    if valid_params(params)
      account = params['meta']['account']
    else
      return
    end

    PUNK.start('new')
    RAGENT.api.mdi.tools.log.debug("\n\n\n\nServer: new incoming poke:\n#{params}")
    PUNK.end('new','ok','in',"SERVER <- POKE : receive new poke")
    SDK_STATS.stats['server']['received'][6] += 1


    # forward to each agent
    RAGENT.user_class_poke_subscriber.get_subscribers.each do |user_agent_class|
      io_rule = user_agent_class.internal_config_io_fetch_first('poke')
      next if io_rule == nil

      begin
        PUNK.start('damned')
        env = {
          'account' => account,
          'agent_name' => user_agent_class.agent_name
        }

        apis = USER_API_FACTORY.gen_user_api(user_agent_class, env)

        # create poke object
        poke = apis.mdi.dialog.create_new_poke(params)

        # set associated api as current sdk_api
        apis.initial_event_content = poke.clone
        set_current_user_api(apis)

        # check route loop
        looped = poke.meta['event_route'].select {|route| route["name"] == user_agent_class.agent_name }.first
        if looped != nil
          PUNK.start('loopdrop')
          RAGENT.api.mdi.tools.log.warn("Loop detected. Dropping incoming poke #{poke.id}")
          PUNK.end('loopdrop','warn','notif',"Loop detected. AGENT:#{user_agent_class.agent_name}TNEGA drop incoming poke #{poke.id}")
          next
        end


        PUNK.start('new')
        RAGENT.api.mdi.tools.log.debug("#{user_agent_class.agent_name}: new incoming poke:\n#{poke.inspect}")
        PUNK.end('new','ok','in',"AGENT:#{user_agent_class.agent_name}TNEGA <- POKE")

        # process it, should never fail, but if its happen we will have a wrong error on parse fail but no deadlock
        user_agent_class.handle_poke(poke.clone)
      rescue Exception => e
        RAGENT.api.mdi.tools.print_ruby_exception(e)
        RAGENT.api.mdi.tools.log.info("Ragent error parse poke :\n#{params}")
        RUBY_AGENT_STATS.report_an_error("ragent poke parse fail", "#{e}")
        SDK_STATS.stats['server']['err_parse'][6] += 1
        SDK_STATS.stats['server']['internal_error'] += 1
        PUNK.end('damned','ko','in',"SERVER <- poke : parse params fail")
      ensure
        PUNK.drop('damned')
        release_current_user_api
      end

    end # each user_agent_class

  end # handle_poke



  # Message handler for an agent which has subscribed to an arbitrary queue
  def self.handle_other_queue(params, queue_name)

    PUNK.start('new')
    RAGENT.api.mdi.tools.log.debug("\n\n\n\nServer: new incoming message on queue '#{queue_name}':\n#{params}")
    PUNK.end('new','ok','in',"SERVER <- MESSAGE : receive from queue #{queue_name}")

    # TODO: add stats

    # forward to agents
    RAGENT.user_class_other_subscribers(queue_name).get_subscribers.each do |user_agent_class|
      begin
        PUNK.start("damned")
        env = {
          'account' => 'other_queue',
          'agent_name' => user_agent_class.agent_name
        }
        apis = USER_API_FACTORY.gen_user_api(user_agent_class, env)
        set_current_user_api(apis)
        user_agent_class.handle_other_queue(params, queue_name)
      ensure
        PUNK.drop("damned")
        release_current_user_api
      end

    end

  end


  # futur !
  def self.handle_alert(params)

    RAGENT.api.mdi.tools.log.info("new alert")

  end # handle_alert

end

RIM = RagentIncomingMessage
