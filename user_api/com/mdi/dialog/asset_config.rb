module UserApis
  module Mdi
    module Dialog
      # Asset Config
      # @api public
      class AssetConfigClass < Struct.new(:asset, :account, :notification_url, :metadata)

        # @!attribute [rw] asset
        #   @api public
        #   @return [String] the IMEI or a similar unique identifier of the asset

        # @!attribute [rw] account
        #   @api public
        #   @return [String] name of the account for this asset ("unstable", "municio", ...)

        # @!attribute [rw] notification_url
        #   @api public
        #   @return [String] the notification url of the asset.

        # @!attribute [rw] metadata
        #   @api public
        #   @return [String] the metadata associated with the asset.

        #   @api private
        def initialize(apis, struct = nil)
          @user_apis = apis

          if struct == nil
            raise "AssetConfig need a struct to be initialized"
          else
            self.account = struct['meta']['account']
            payload = struct['payload']
            self.asset = payload['imei']
            self.notification_url = payload['notification_url']
            self.metadata = payload['metadata']
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
          r_hash['asset'] = self.asset
          r_hash['account'] = self.account
          r_hash['notification_url'] = self.notification_url
          r_hash['metadata'] = self.metadata
          r_hash.delete_if { |k, v| v.nil? }
          r_hash
        end

      end #AssetConfig
    end #Dialog
  end #Mdi
end #UserApis
