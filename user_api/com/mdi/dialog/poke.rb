#########################################################
# Xavier Demompion : xavier.demompion@mobile-devices.fr
# Mobile Devices 2014
#########################################################


# {"asset"=>"354676050177152", "created_at"=>nil, "namespace"=>"ASSET_CAMPAIGN::STATUS",
#   "payload"=>"lol",
#   "received_at"=>"\xCET-W\xD6", "sender"=>"DEVICE_MANAGER", "updated_at"=>nil, "id"=>628951424566296793}, meta: {"account"=>"ciinte"}




module UserApis
  module Mdi
    module Dialog
      # Poke, a generic nofication
      # @api public
      class PokeClass < Struct.new(:id, :asset, :account, :created_at, :updated_at, :received_at, :sender, :namespace, :content, :meta)

        # @!attribute [rw] id
        #   @api public
        #   @return [Integer] a unique message ID set by the server.
        #   Don't touch this


        # @!attribute [rw] asset
        #   @api public
        #   @return [String] the IMEI or a similar unique identifier of sender of the track data

        # @!attribute [rw] account
        #   @api public
        #   @return [String] name of the account for this message ("unstable", "municio", ...)

        # @!attribute [rw] created_at
        #   @api public
        #   @return [Bignum] when the poke was created

        # @!attribute [rw] updated_at
        #   @api public
        #   @return [Bignum]when the poke was updated_at by something

        # @!attribute [rw] received_at
        #   @api public
        #   @return [Bignum] when the track was received by the server

        # @!attribute [rw] sender
        #   @api public
        #   @return [String] who did this.

        # @!attribute [rw] namespace
        #   @api public
        #   @return [String] namespace of the poke

        # @!attribute [rw] content
        #   @api public
        #   @return [String] the payload of the poke. That is the part your agent will deal with.


        # @!attribute [rw] meta
        #   @api public
        #   @return [Hash] some metadata for the poke

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
              'class' => 'poke',
              'account' => account,
              'event_route' => []
            }
            self.account = account
            self.created_at = Time.now.to_i
          else
            self.meta = struct['meta']
            self.meta = {} if !(self.meta.is_a? Hash)
            self.meta['class'] = 'poke'
            self.meta['event_route'] ||= []

            payload = struct['payload']

            self.id = payload['id']
            self.asset = payload['asset']
            self.account = self.meta['account']
            self.created_at = payload['created_at']
            self.updated_at = payload['updated_at']
            self.received_at = payload['received_at']
            self.sender = payload['sender']
            self.namespace = payload['namespace']
            self.content = payload['content']

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
            'created_at' => self.created_at.to_i,
            'updated_at' => self.updated_at.to_i,
            'received_at' => self.received_at.to_i,
            'sender' => self.sender,
            'namespace' => self.namespace,
            'payload' => self.content
          }

          r_hash['meta'].delete_if { |k, v| v.nil? }
          r_hash['payload'].delete_if { |k, v| v.nil? }
          r_hash
        end

        # @return [Hash] a hash representation of this event in the format to be sent to the cloud (data injection)
        # @api private
        def to_hash_to_send_to_cloud
          r_hash = {}
          r_hash['meta'] = {
            'account' => self.account,
            'class' => 'poke',
            'event_route' => self.meta['event_route']
          }
          r_hash['payload'] = {
            'id' => CC.indigen_next_id(self.asset),
            'asset' => self.asset,
            'created_at' => self.created_at.to_i,
            'updated_at' => self.updated_at == nil ? Time.now.to_i : self.updated_at.to_i,
            'received_at' => self.received_at == nil ? Time.now.to_i : self.received_at.to_i,
            'sender' => self.sender, # todo: add in model of db viewer (todo)
            'namespace' => self.namespace,
            'payload' => self.content
          }

          r_hash['meta'].delete_if { |k, v| v.nil? }
          r_hash['payload'].delete_if { |k, v| v.nil?}
          r_hash
        end

      end #Track
    end #Dialog
  end #Mdi
end #UserApis
