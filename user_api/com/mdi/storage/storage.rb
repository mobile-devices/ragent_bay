#########################################################
# Xavier Demompion : xavier.demompion@mobile-devices.fr
# Mobile Devices 2013
#########################################################

require_relative 'tracking_field_mapping'
require_relative 'collection_definitions_mapping'
require_relative 'stats_definitions_mapping'

module UserApis
  module Mdi

    # @api public
    class StorageClass

      # @api private
      def initialize(apis)
        @user_apis = apis
      end

      # @api private
      def user_api
        @user_apis
      end

      # This is your redis cache.
      # @note Rememeber that it can be deleted at any moment, and you do share this cache with other instance of your agent in the cloud.
      # @param [String] you can specify a namespace to use different redis object.
      # @example
      #   user_api.mdi.storage.redis['last operation'] = Time.now
      #   user_api.mdi.storage.redis.hget("fuelNames", local)
      #   listjson = user_api.mdi.storage.redis.zrangebyscore(key, elem1, elem2)
      # @see http://redis.io/commands for more details about available commands.
      def redis(id = 'default')
        @user_redis ||= {}
        @user_redis[id] ||= Redis::Namespace.new("RR:#{user_api.agent_name}_#{id}", :redis => CC.redis)
      end


      # This is your distributed and replicated solid data base, based with mongodb. All data stored in it will be shared between all instances of you agent running into the cloud.
      # @note: don't put too much data in it, or it will cost you a lot of money :)
      # @see http://api.mongodb.org/ruby/current/ for more details about available commands.
      # If you willing to use mongo into your vm, you NEED ton install it first (advanced user only) with # http://docs.mongodb.org/manual/tutorial/install-mongodb-on-debian/
      # vagrant ssh will help you to log into you virtual cloud
      # @return a Mongo::DB
      def mongodb
        CC.mongoClient.use("#{user_api.agent_name}").database
      end

      # @api_private
      def tracking_fields_info
        @tracking_fields_info ||= Storage::TrackFieldMappingClass.new(user_api)
      end

      # Allows you to access account collection definitions
      def collection_definitions
        @collection_definitions ||= Storage::CollectionDefinitionsMappingClass.new(user_api)
      end

      # Allows you to access account stats definitions
      def stats_definitions
        @stats_definitions ||= Storage::StatsDefinitionsMappingClass.new(user_api)
      end

      # This is where your configuration is stored (setted in config/your_agent.yml)
      def config
        @config ||= user_api.user_class.user_config
      end

      # Gives you statics informations
      def static_env_info
        {'runtime_id' => RAGENT.runtime_id_code}
      end

      # @api_private
      def agent_root_path
        user_api.user_class.root_path
      end

    end

  end
end
