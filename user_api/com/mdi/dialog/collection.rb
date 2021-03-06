#########################################################
# Xavier Demompion : xavier.demompion@mobile-devices.fr
# Mobile Devices 2014
#########################################################


module UserApis
  module Mdi
    module Dialog
      # A class that represents a standard collection. Basically it is a list of presence/message/track record with a start and an end time for a specific asset.
      # @api public
      class CollectionClass < Struct.new(:name, :type, :meta, :account, :id, :asset, :start_at, :stop_at, :data)

        # @!attribute [rw] name
        #   @api public
        #   @return [String] name of the collection

        # @!attribute [rw] type
        #   @api public
        #   @return [String]  always equal to 'collection'

        # @!attribute [rw] meta
        #   @api public
        #   @return [Hash] some metadata for the message, can be nil.

        # @!attribute [rw] account
        #   @api public
        #   @return [String] name of the account for this message ("unstable", "municio", ...)

        # @!attribute [rw] id
        #   @api public
        #   @return [Integer] a unique message ID set by the server.

        # @!attribute [rw] asset
        #   @api public
        #   @return [String] the IMEI or a similar unique identifier of the asset who sent this message (if the essage if coming from a device).

        # @!attribute [rw] start_at
        #   @api public
        #   @return [Bignum] a timestamp indicating when the collection started

        # @!attribute [rw] stop_at
        #   @api public
        #   @return [Bignum] a timestamp indicating when the collection ended


        # @!attribute [rw] data
        #   @api public
        #   @return [Array] of object (presence/message/track ...)

        # @api private
        def initialize(apis, struct = nil)

          @user_apis = apis

          # usable account ?
          account = nil
          begin
            account = apis.account
          rescue Exception => e # Silent !
          end

          self.type = 'collection'

          if struct.blank?
            self.name = 'unknown'
            self.meta = {
              'class' => 'collection',
              'account' => account,
              'event_route' => []
            }
            self.account = account
            self.id = nil
            self.asset = ''
            self.start_at = 0
            self.stop_at = 0
            self.data = []
          else
            self.meta = struct['meta']
            self.meta = {} if !(self.meta.is_a? Hash)
            self.meta['class'] = 'collection'
            self.meta['event_route'] ||= []

            payload = struct['payload']

            self.name = payload['name']
            self.account = self.meta['account']
            self.id = payload['id']
            self.asset = payload['asset']
            self.start_at = payload['start_at'].to_i
            self.stop_at = payload['stop_at'].to_i

            # TODO futur: raise if self.meta.class != 'collection'

            self.data = []
            if payload['data'].is_a? Array
              payload['data'].each do |el|

                klass = el['meta']['class']

                raise "Undefined class #{el['meta']}" if klass == nil

                case klass
                when 'presence'
                  self.data << user_api.mdi.dialog.create_new_presence(el)
                when 'message'
                  self.data << user_api.mdi.dialog.create_new_message(el)
                when 'track'
                  self.data << user_api.mdi.dialog.create_new_track(el)
                end

              end
            end

          end
        end

        # @api private
        def user_api
          @user_apis
        end


         # ex
         #{"meta":{"account":"unstable"},"payload":{"id":561902626124333056,"id_str":"561902626124333056","asset":"FAKE0000001635","name":"My trips","start_at":1974,"stop_at":1974,
         # "tracks":[{"id":"545648584880832729","asset":"kikoo","recorded_at":134567865,"recorded_at_ms":134567865,"received_at":5678545,"longitude":"236561.0","latitude":"4896980.0","14":"MQ=="}]}}

        # @return [Hash] a hash representing this collection.
        # @api private
        def to_hash
          r_hash = {}

          # build data
          data = []
          self.data.each do |el|
            data << el.to_hash
          end

          r_hash['meta'] = self.meta
          r_hash['meta'] = {} if r_hash['meta'] == nil
          r_hash['meta']['account'] = self.account
          r_hash['payload'] = {
            'id' => self.id,
            'asset' => self.asset,
            'name' => self.name,
            'start_at' => self.start_at.to_i,
            'stop_at' => self.stop_at.to_i,
            'data' => data
          }
          r_hash['meta'].delete_if { |k, v| v.nil? }
          r_hash['payload'].delete_if { |k, v| v.nil? }

          r_hash
        end

        def to_hash_to_send_to_cloud
          self.id = CC.indigen_next_id(self.asset)
          self.to_hash
        end


        # compute and set the start_at and stop_at from data stored in collection
        # @return random
        # @api public
        def crop_start_stop_time_from_data
          # use recorded at (for tracks & message), time for presence
          start_at = nil
          stop_at = nil

          self.data.each do |el|
            if el.id != nil
              mom = nil
              CC.logger.debug("crop_start_stop_time_from_data of #{el.class}: #{el}")
              case "#{el.class}"
              when "UserApis::Mdi::Dialog::PresenceClass"
                mom = el.time
              when "UserApis::Mdi::Dialog::MessageClass"
                mom = el.recorded_at
              when "UserApis::Mdi::Dialog::TrackClass"
                mom = el.recorded_at
              end

              raise "Couldn't find time associated with a #{el.class}" if mom == nil

              start_at ||= mom
              stop_at ||= mom
              start_at = mom if mom < start_at
              stop_at = mom if mom > stop_at

            end
          end

          self.start_at = start_at
          self.stop_at = stop_at

        end

      end #Collection
    end #Dialog
  end #Mdi
end #UserApis
