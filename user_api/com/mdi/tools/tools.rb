#########################################################
# Xavier Demompion : xavier.demompion@mobile-devices.fr
# Mobile Devices 2013
#########################################################

require_relative 'log'
require_relative 'subscriber'
require_relative 'protogen'


module UserApis
  module Mdi

    # @api public
    class ToolsClass
      # @api private
      def initialize(apis)
        @user_apis = apis
      end
      # @api private
      def user_api
        @user_apis
      end
      # @api private
      def print_env_info
        p user_api.user_environment
      end
      # @api public
      # use it when you had raised an exception and you want to print a beautiful stack trace of it
      # @example
      #    begin
      #      Math.sqrt(-1)
      #    rescue Exception => e
      #      user_api.mdi.tools.print_ruby_exception(e)
      #    end
      def print_ruby_exception(e, stack_len = 20)
        stack=""
        e.backtrace.take(stack_len).each do |trace|
          stack+="  >> #{trace}\n"
        end
        log.error("  RUBY EXCEPTION >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>\n >> #{e.inspect}\n\n#{stack}\n>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>")
      end

      # @api public
      def send_error(e, event)
        # must be impl #
      end

      # @api public
      # A logger correctly configured for your environment.
      # @see Tools::LogClass
      def log
        @log ||= Tools::LogClass.new(user_api)
      end
      # @api private
      def create_new_subscriber
        Tools::SubscriberClass.new(user_api)
      end
      # @api public
      # your protogen object according to your protocol defined in configuration
      # @see Tools::ProtogenClass
      def protogen
        @protogen ||= Tools::ProtogenClass.new(user_api)
      end

    end

  end
end
