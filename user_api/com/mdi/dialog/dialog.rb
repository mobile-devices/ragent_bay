#########################################################
# Xavier Demompion : xavier.demompion@mobile-devices.fr
# Mobile Devices 2013
#########################################################

require_relative 'presence'
require_relative 'message'
require_relative 'track'
require_relative 'order'
require_relative 'collection'
require_relative 'poke'
require_relative 'asset_config'
require_relative 'cloud_gate'
require_relative 'device_gate'


module UserApis
  module Mdi

    # @api public
    class DialogClass
      # @api private
      def initialize(apis)
        @user_apis = apis
      end
      # @api private
      def user_api
        @user_apis
      end

      # @api public
      # Create a new presence object
      # @example
      #   new_presence = user_api.mdi.dialog.create_new_presence
      def create_new_presence(struct = nil)
        Dialog::PresenceClass.new(user_api, struct)
      end

      # @api public
      # Create a new message object
      # @example
      #   new_message = user_api.mdi.dialog.create_new_message
      def create_new_message(struct = nil)
        Dialog::MessageClass.new(user_api, struct)
      end

      # @api public
      # Create a new track object
      # @example
      #   new_track = user_api.mdi.dialog.create_new_track
      def create_new_track(struct = nil)
        Dialog::TrackClass.new(user_api, struct)
      end

      # @api public
      # Create a new order object
      # @example
      #   new_order = user_api.mdi.dialog.create_new_order
      def create_new_order(struct = nil)
        Dialog::OrderClass.new(user_api, struct)
      end

      # @api public
      # Create a new collection object
      # @example
      #   new_collection = user_api.mdi.dialog.create_new_collection
      def create_new_collection(struct = nil)
        Dialog::CollectionClass.new(user_api, struct)
      end

      # @api public
      # Create a new poke object
      # @example
      #   new_poke= user_api.mdi.dialog.create_new_poke
      def create_new_poke(struct = nil)
        Dialog::PokeClass.new(user_api, struct)
      end

      # @api private
      # Create a new asset config object
      # @example
      #   new_asset_config= user_api.mdi.dialog.create_new_asset_config
      def create_new_asset_config(struct = nil)
        Dialog::AssetConfigClass.new(user_api, struct)
      end

      # @api public
      # @see Dialog::DeviceGateClass
      def device_gate
        Dialog::DeviceGateClass.new(user_api, user_api.user_class.managed_message_channels[0])
      end

      # @api public
      # @see Dialog::CloudGateClass
      def cloud_gate
        Dialog::CloudGateClass.new(user_api, user_api.user_class.managed_message_channels[0])
      end

    end

  end
end
