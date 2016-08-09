#########################################################
# Xavier Demompion : xavier.demompion@mobile-devices.fr
# Mobile Devices 2013
#########################################################


module UserApis
  module Mdi
    module Dialog
      # An order is a object you received if you schedule some tasks into your config/schedule.rb
      # @api public
      class OrderClass < Struct.new(:agent, :code, :params)

        # @!attribute [rw] agent
        #   @api public
        #   @return [String] agent name that the order is for

        # @!attribute [rw] code
        #   @api public
        #   @return [String] the code of the order

        # @!attribute [rw] params
        #   @api public
        #   @return [String] params that can be necessary for you to execute the order


        # @api private
        def initialize(apis, struct = nil)
          @user_apis = apis

          if struct == nil
            raise "Order need a struct to be initialized"
          else
            self.agent = struct['agent']
            self.code = struct['order']
            self.params = struct['params']

            agent = RAGENT.get_agent_from_name(struct['agent'])
            if agent == nil
              raise AgentNotFound , "Server: agent #{self.agent} is not running on this bay"
            end
          end
        end

        # @api private
        def user_api
          @user_apis
        end

        # @return a hash representation of this order. See constructor documentation for format.
        # @api private
        def to_hash
          r_hash = {}
          r_hash['agent'] = self.agent
          r_hash['code'] = self.code
          r_hash['params'] = self.params
          r_hash.delete_if { |k, v| v.nil? }
        end

      end #OrderClass
    end #Dialog
  end #Mdi
end #UserApis
