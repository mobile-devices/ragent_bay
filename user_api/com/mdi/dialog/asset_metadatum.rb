module UserApis
  module Mdi
    module Dialog
      # Asset Metadatum
      # @api public
      class AssetMetadatumClass < Struct.new(:name, :type, :value)

        # @!attribute [rw] name
        #   @api public
        #   @return [String] the name of the asset metadatum.

        # @!attribute [rw] type
        #   @api public
        #   @return [String] the type of the asset metadatum ('string', 'integer', 'boolean', 'float', 'json').

        # @!attribute [rw] value
        #   @api public
        #   @return [String] the value of the asset metadatum.

        # @api private
        def initialize(struct = nil)
          if struct == nil
            raise "AssetMetadatum need a struct to be initialized"
          else
            self.name = struct['name']
            self.type = struct['type']
            self.value = struct['value']
          end
        end

        # @return [Hash] a hash representation of this event. See constructor documentation for the format.
        # @api private
        def to_hash(without_fields = false)
          r_hash = {}
          r_hash['name'] = self.name
          r_hash['type'] = self.type
          r_hash['value'] = self.value
          r_hash.delete_if { |k, v| v.nil? }
          r_hash
        end

      end #AssetMetadatum
    end #Dialog
  end #Mdi
end #UserApis
