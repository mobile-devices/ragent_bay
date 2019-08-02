#########################################################
# Xavier Demompion : xavier.demompion@mobile-devices.fr
# Mobile Devices 2013
#########################################################


module UserApis
  module Mdi
    module Dialog
      # Track data sent by a device or injected by cloud. Tracks are geolocalised data that can be sent with a optimized format over the wire.
      # @api public
      class TrackClass < Struct.new(:id, :asset, :latitude, :longitude, :recorded_at, :received_at, :fields_data, :account, :meta)

        # @!attribute [rw] id
        #   @api public
        #   @return [Integer] a unique message ID set by the server.
        #   Don't touch this


        # @!attribute [rw] asset
        #   @api public
        #   @return [String] the IMEI or a similar unique identifier of sender of the track data


        # @!attribute [rw] latitude
        #   @api public
        #   @return [Float] latitude of the asset position when the track was recorded, in degree * 10^-5

        # @!attribute [rw] longitude
        #   @api public
        #   @return [Float] longitude of the asset position when the track was recorded, in degree * 10^-5

        # @!attribute [rw] recorded_at
        #   @api public
        #   @return [Float] when the track was recorded by the device or the provider

        # @!attribute [rw] received_at
        #   @api public
        #   @return [Bignum] when the track was received by the server

        # @!attribute [rw] fields_data
        #   @api public
        #   @return [Array<Hash{String => Object}>] the array of fields collected for this track.
        #                                           A field look like this: `
        #                                           {
        #                                               "name": "GPRMC_VALID",
        #                                               "field": 3,
        #                                               "field_type": "int",
        #                                               "size": 1,
        #                                               "ack": 1,
        #                                               "raw_value": 42,
        #                                               "value":42,
        #                                               "fresh":false,
        #                                               "recorded_at", 687416315
        #                                           } `
        #
        #   @note You should not use the `raw_value` of the field as it differs between the SDK VM and the real cloud.

        # @!attribute [rw] account
        #   @api public
        #   @return [String] name of the account for this message ("unstable", "municio", ...)

        # @!attribute [rw] meta
        #   @api public
        #   @return [Hash] some metadata for the message, can be nil.

        #   @api private
        def initialize(apis, struct = nil)
          @user_apis = apis

          # usable account ?
          account = nil
          begin
            account = apis.account
          rescue Exception => e # Silent !
          end


          if struct.blank?
            self.meta = {
              'class' => 'track',
              'account' => account,
              'event_route' => []
            }
            self.account = account
            self.fields_data = []
          else
            self.meta = struct['meta']
            self.meta = {} if !(self.meta.is_a? Hash)
            self.meta['class'] = 'track'
            self.meta['event_route'] ||= []

            payload = struct['payload']

            self.id = payload['id']
            self.asset = payload['asset']
            self.account = self.meta['account']


            io_rule = apis.user_class.internal_config_io_fetch_first('track')

            if io_rule['track_hide_location']
              self.latitude = nil
              self.longitude = nil
            else
              self.latitude = payload['latitude'] == nil ? nil : payload['latitude'].to_f
              self.longitude = payload['longitude'] == nil ? nil : payload['longitude'].to_f
            end

            if io_rule['track_hide_time']
              self.recorded_at = nil
              self.received_at = nil
            else
              self.recorded_at = payload['recorded_at'].to_f
              self.received_at = payload['received_at'].to_i
            end

            self.fields_data = []
            dropped_fields = []

            # Old format of tracks:
            #   {..., "9" => "AABvvA==", "8" => "AAAj2g=="}
            # New format of tracks:
            #   {..., "fields" => [{"id" => 9, "name" => "GPS_DIR",   "data" => "AABvvA=="},
            #                      {"id" => 8, "name" => "GPS_SPEED", "data" => "AAAj2g=="}]}
            # For now we reformat tracks with the old version into the new version
            #   before treating them.
            unless payload['fields']
              payload['fields'] = []
              payload.each do |k, v|
                field = apis.mdi.storage.tracking_fields_info.get_by_id(k, true)
                next if field == nil
                payload['fields'] << {
                  'id' => k.to_i,
                  'name' => field['name'],
                  'data' => v
                }
              end
            end

            payload['fields'].each do |track_field|
              k = track_field['id']
              v = track_field['data']
              field = apis.mdi.storage.tracking_fields_info.get_by_id(k, true)
              next if field == nil
              RAGENT.api.mdi.tools.log.debug("init track with track gives #{k} #{v} #{field}")

              # filter it if needed
              w_fields = io_rule['allowed_track_fields']
              RAGENT.api.mdi.tools.log.debug(w_fields)
              if w_fields != nil and !w_fields.include?('ALL_FIELDS') and !w_fields.include?(field['name'])
                dropped_fields << "#{field['name']}"
                next
              end

              field['raw_value'] = v
              field['value'] = v
              field['fresh'] = false
              field['recorded_at'] = self.recorded_at

              # decode if Ragent. In VM mode, raw_value = value, nothing else to do
              # Note that the raw_value is thus different between VM mode and Ragent.
              if RAGENT.running_env_name == 'ragent'
                # basic decode
                case field['field_type']
                when 'integer'
                  # reverse: b64_value =  Base64.strict_encode64([demo].pack("N").unpack("cccc").pack('c*'))
                  field['value'] = v.to_s.unpack('B*').first.to_i(2)
                when 'string'
                  field['value'] = v.to_s
                when 'boolean'
                  field['value'] = v.to_s == "\x01" ? true : false
                when 'double'
                  field['value'] = v.to_s.unpack('E').first
                end
              end
              #idea: metric for pos, speed

              self.fields_data << field
            end # each element of payload
            RAGENT.api.mdi.tools.log.debug("track init: dropping #{dropped_fields.size} fields:  [#{dropped_fields.join(' ')}]") if dropped_fields.size > 0 # print at once to avoid potential log spam

          end

        end

        # @api private
        def user_api
          @user_apis
        end

        # @return [Hash] a hash representation of this event. See constructor documentation for the format.
        # @api private
        def to_hash(without_fields = false)
          r_hash = {}
          r_hash['meta'] = self.meta
          r_hash['payload'] = {
            'id' => self.id,
            'asset' => self.asset,
            'recorded_at' => self.recorded_at.to_f,
            'received_at' => self.received_at.to_i,
            'latitude' => self.latitude == nil ? nil : self.latitude.to_f,
            'longitude' => self.longitude == nil ? nil : self.longitude.to_f
          }
          if !without_fields
            #add field of new data (and convert it as magic string)
            r_hash['payload']['fields'] = []
            self.fields_data.each do |field|
              CC.logger.debug("to_hash: Adding field '#{field['field']}' with val= #{field['value']}")

              # [DEPRECATED] Old track format
              r_hash['payload'][field['field'].to_s] = "#{field['raw_value']}"
              # New track format
              r_hash['payload']['fields'] << {'id' => field['field'], 'name' => "#{field['name']}", 'data' => "#{field['raw_value']}"}
          end
          end

          r_hash['meta'].delete_if { |k, v| v.nil? }
          r_hash['payload'].delete_if { |k, v| v.nil? and k != 'latitude' and k != 'longitude'}
          r_hash
        end

        # @return [Hash] a hash representation of this event in the format to be sent to the cloud (data injection)
        # @api private
        def to_hash_to_send_to_cloud
          r_hash = {}
          r_hash['meta'] = {
            'account' => self.account,
            'class' => 'track',
            'event_route' => self.meta['event_route'],
            'isMemberOfCollection' => self.meta['isMemberOfCollection']
          }
          r_hash['payload'] = {
            'id' => (self.id = CC.indigen_next_id(self.asset)),
            'sender' => 'ragent', # todo: add in model of db viewer (todo)
            'asset' => self.asset,
            'received_at' => Time.now.to_i,
            'recorded_at' => self.recorded_at == nil ? Time.now.to_i : self.recorded_at.to_f,
            'latitude' => self.latitude == nil ? nil : self.latitude.to_f,
            'longitude' => self.longitude == nil ? nil : self.longitude.to_f
          }

          #add  fresh field of new data (and convert it as magic string)
          a_field = false
          if self.fields_data.is_a? Array # in cas on nil or whatever
            r_hash['payload']['fields'] = []
            self.fields_data.each do |field|
              if field['fresh'] and field['field'] > 4999 # can't inject field from 0 to 4999, device protected
                CC.logger.debug("to_hash_to_send_to_cloud: Adding field '#{field['field']}' with val= #{field['value']}")

                # [DEPRECATED] Old track format
                r_hash['payload']["#{field['field']}"] = "#{field['raw_value']}"
                # New track format
                r_hash['payload']['fields'] << {'id' => field['field'], 'name' => "#{field['name']}", 'data' => "#{field['raw_value']}"}

                a_field = true
                r_hash['meta']['include_fresh_track_field'] = true
              else
                CC.logger.warn("to_hash_to_send_to_cloud: dropping field #{field}. (index < 5000)")
              end
            end
          end

          raise "Can't cast a track without valid field to be sent to the cloud." if !a_field

          r_hash['meta'].delete_if { |k, v| v.nil? }
          r_hash['payload'].delete_if { |k, v| v.nil? and k != 'latitude' and k != 'longitude'}
          r_hash
        end


        # set_field alter the value of a field
        # @api public
        # @example change the value of track MDI_CC_LEGAL_SPEED to "50"
        #   new_track.set_field("MDI_CC_LEGAL_SPEED", "50")
        def set_field(name, value)
          field = user_api.mdi.storage.tracking_fields_info.get_by_name(name, self.account)
          if field == nil
            RAGENT.api.mdi.tools.log.warn("set_field: Field #{name} not found in local configuration, abort")
            return self.fields_data
          end

          # verify value type
          case field['field_type']
          when 'integer'
            raise "#{value} is not an integer" if "#{value}" != "#{value.to_i}"
          when 'string'
            # NOP
          when 'boolean'
            raise "#{value} is not a boolean" if ("#{value}" != 'true' and "#{value}" != 'false')
          when 'double'
            raise "#{value} is not a double" if "#{value}" != "#{value.to_f}"
          end

          raw_value = value
          # decode if Ragent. In VM mode, raw_value = value, nothing else to do
          # let's reproduce the device encoding
          if RAGENT.running_env_name == 'ragent'
            case field['field_type']
            when 'integer'
              # field['value'] = v.to_s.unpack('B*').first.to_i(2)
              # reverse: b64_value =  Base64.strict_encode64([demo].pack("N").unpack("cccc").pack('c*'))
              raw_value = [value.to_i].pack("N").unpack("cccc").pack('c*')
            when 'string'
              # field['value'] = v.to_s
              raw_value = value
            when 'boolean'
              # field['value'] = v.to_s == "\x01" ? true : false
              raw_value = value ? "\x01" : "\x00"
            when 'double'
              # field['value'] = v.unpack('E').first # little endian
              raw_value = [value.to_f].pack('E')
            end
          end

          field['name'] = name
          field['raw_value'] = raw_value
          field['value'] = value
          field['fresh'] = true
          self.recorded_at = Time.now.to_i
          self.fields_data << field
          self.id = nil # invalid track because some field has changed
        end

        # get the value of a field in this track
        # @api public
        # @param [field_name_or_id] field name or id
        # @param [also_fetch_in_last_known_if_available] true/false
        # @return a field
        #                                           A field look like this: `
        #                                           {
        #                                               "name": "GPRMC_VALID",
        #                                               "field": 3,
        #                                               "field_type": "int",
        #                                               "size": 1,
        #                                               "ack": 1,
        #                                               "raw_value": 42,
        #                                               "value":42,
        #                                               "fresh":false
        #                                               "recorded_at", 687416315
        #                                           } `
        # @example get the value of track MDI_CC_LEGAL_SPEED
        #   field = track.field('MDI_CC_LEGAL_SPEED')
        #   speed = field['value']
        def field(field_name_or_id, also_fetch_in_last_known_if_available = false)
          name = ''
          case field_name_or_id.class.to_s
          when 'String'
            name = field_name_or_id
          when 'Fixnum'
            name = user_api.mdi.storage.tracking_fields_info.get_by_id(field_name_or_id, self.account)['name']
          else
            raise "#{field_name_or_id} is neither an integer nor a string"
          end

          # filter it if needed (to be sure)
          io_rule = user_api.user_class.internal_config_io_fetch_first('track')
          w_fields = io_rule['allowed_track_fields']
          raise "field: you want to use field #{name} but It is not in your whitelist." if w_fields != nil and  !w_fields.include?('ALL_FIELDS') and !w_fields.include?(name)

          field = self.fields_data.select{|e| e['name'] == name }.first
          RAGENT.api.mdi.tools.log.debug("track.field: Field #{field_name_or_id} not found in current track") if field == nil

          if field == nil and also_fetch_in_last_known_if_available and self.meta['fields_cached'] != nil
            cache = self.meta['fields_cached']

            # map["#{field['name']}|recorded_at"] = field['recorded_at']
            # map["#{field['name']}|raw_value"] = field['raw_value']
            if cache["#{name}|recorded_at"] != nil
              field = user_api.mdi.storage.tracking_fields_info.get_by_name(name, true)
              if field != nil
                field['raw_value'] = Base64.strict_decode64(cache["#{name}|raw_value"])
                field['value'] = field['raw_value']
                field['fresh'] = false
                field['recorded_at'] = cache["#{name}|recorded_at"]

                # decode if Ragent. In VM mode, raw_value = value, nothing else to do
                # Note that the raw_value is thus different between VM mode and Ragent.
                if RAGENT.running_env_name == 'ragent'
                  # basic decode
                  case field['field_type']
                  when 'integer'
                    # reverse: b64_value =  Base64.strict_encode64([demo].pack("N").unpack("cccc").pack('c*'))
                    field['value'] = field['value'].to_s.unpack('B*').first.to_i(2)
                  when 'string'
                    field['value'] = field['value'].to_s
                  when 'boolean'
                    field['value'] = field['value'].to_s == "\x01" ? true : false
                  when 'double'
                    field['value'] = field['value'].to_s.unpack('E').first
                  end # case type for decode
                end # in ragent mode
                RAGENT.api.mdi.tools.log.debug("Found field from cached :#{field}")
              end # field conf exists
            end # field exits
          end # field is nil fetch into olds

          field
        end


        # flush fields stored
        # @api public
        def clear_fields
          self.fields_data = []
        end

      end #Track
    end #Dialog
  end #Mdi
end #UserApis
