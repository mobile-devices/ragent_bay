module RagentApi
  module StatsDefinitionMapping

    def self.invalid_map
      @mapping_stats_definitions_number = nil
    end

    def self.fetch_default_map
      @default_stats_definitions ||= begin
        path = File.expand_path("..", __FILE__)
        CC.logger.info("fetch_default_map fetched")
        JSON.parse(File.read("#{path}/default_stats_definitions_info.json"))
      end
    end

    def self.alter_definition(name, account, val)
      return if @mapping_stats_definitions_number == nil
      return if @mapping_stats_definitions_number[account] == nil # no need to update absent account
      definition = RagentApi::StatsDefinitionMapping.get_by_name(name, account, true)
      @mapping_stats_definitions_number[account].delete(definition)
      if val != nil
        @mapping_stats_definitions_number[account] << val
      end
    end

    def self.fetch_map(account)

      @mapping_stats_definitions_number ||= { 'default' =>  self.fetch_default_map }

      if !(@mapping_stats_definitions_number.has_key?(account))
        CC.logger.info("Stats definitions fetch_map #{account}")
        ret = CC::RagentHttpApiV3.request_http_cloud_api(account, '/stats_definitions.json')
        if ret != nil
          CC.logger.info("Stats definitions fetch_map success for account #{account} = #{ret}")
          @mapping_stats_definitions_number[account] = ret
        else
          raise "Account '#{account}' not available."
        end
      end
      @mapping_stats_definitions_number[account]
    end

    # stats definitions look like :
    # {
    #     "name": "Trips example",
    #     "type": "tracks",
    #     "collect": [ "track", "message" ],
    #     "start_conditions": {
    #       "DIO_IGNITION": true
    #      },
    #     "stop_conditions": {
    #       "DIO_IGNITION": false
    #      },
    #     "assets": [ "FAKE_IMEI" ], # if assets is empty, it means it should match every asset
    # }

    # returns a stats definitions structs array
    def self.get_all(account)
      if RAGENT.running_env_name == 'sdk-vm'
        account = 'default'
      end
      return self.fetch_map(account)
    end

    def self.get_by_name(str_name, account, no_error = false)
      if RAGENT.running_env_name == 'sdk-vm'
        account = 'default'
      end
      fetch_map(account).each do |definition|
        if "#{definition['name']}" == "#{str_name}"
          return definition.clone
        end
      end
      if !no_error
        raise "Stats definition '#{str_name}' not found for account '#{account}'."
      end
    end

  end
end
