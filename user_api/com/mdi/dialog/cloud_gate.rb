#########################################################
# Xavier Demompion : xavier.demompion@mobile-devices.fr
# Mobile Devices 2013
#########################################################


module UserApis
  module Mdi
    module Dialog

      # @api public
      # This class handles all mdi cloud to mdi cloud communication.
      # @note You don't have to instantiate this class yourself.
      #    Use the user_api.mdi.dialog.cloud_gate object which is already configured for your agent.
      class CloudGateClass

        # @api private
        # @param channel [String] the messages passing through this gate will be sent on this channel
        def initialize(apis, default_origin_channel)
          @user_apis = apis
          @default_origin_channel = default_origin_channel
        end

        # @api private
        def user_api
          @user_apis
        end

        def default_origin_channel
          @default_origin_channel
        end


        # Inject a presence in the server queue (ie push a presence to the server)
        # @return true on success
        # @param [PresenceClass] the presence to send
        # @example: NYI
        def inject_presence(presence)
          begin

            raise "Presence id #{presence.id} has already been sent into the cloud. Dropping injection."  if presence.id != nil

            PUNK.start('injectpresence','inject presence to cloud ...')
            out_id = CC.indigen_next_id(presence.asset)

            inject_hash = {
              "meta" => {
                "account" =>     presence.account,
                "class" => 'presence'
                },
                "payload" => {
                "id" =>     out_id,     # Indigen integer
                "asset" =>  "ragent",
                "type" =>   "presence",
                'time' =>   presence.time,
                'bs' => presence.bs,
                'reason' => presence.reason
              }
            }

            inject_hash['meta'].delete_if { |k, v| v.nil? }
            inject_hash['payload'].delete_if { |k, v| v.nil? }


            # todo: put some limitation
            CC.push(inject_hash,'presences')

            # success !
            PUNK.end('injectpresence','ok','out',"SERVER <- SERVER PRESENCE")

            SDK_STATS.stats['agents'][user_api.user_class.agent_name]['inject_to_cloud'] += 1
            return true
          rescue Exception => e
            user_api.mdi.tools.log.error("Error on inject presence")
            user_api.mdi.tools.print_ruby_exception(e)
            PUNK.end('injectpresence','ko','out',"SERVER <- SERVER PRESENCE")
            # stats:
            SDK_STATS.stats['agents'][user_api.user_class.agent_name]['err_on_inject'] += 1
            SDK_STATS.stats['agents'][user_api.user_class.agent_name]['total_error'] += 1
            return false
          end
        end


        # Inject a message in the server queue on a specific channel (ie push a message to the server)
        # @return true on success
        # @param [MessageClass] msg the message to inject
        # @param [String] channel channel the message will be posted to
        # @note Be wary of "infinite message loops" with this method.
        # @note: if id is not nil (ie received from the cloud or duplicated), the injection will fail.
        # @example Injecte a new message to the cloud
        #   new_msg = user_api.mdi.dialog.create_new_message
        #   new_msg.recorded_at = Time.now.to_i
        #   new_msg.asset = "3735843415387632"
        #   new_msg.content = "hello from ruby agent !"
        #   new_msg.account = "my_account"
        #   user_api.mdi.dialog.cloud_gate.inject_message(new_msg, "com.me.services.test_messages")
        def inject_message(msg, channel, origin_channel = default_origin_channel)
          begin
            PUNK.start('injectmsg','inject message to cloud ...')

            raise "Message id #{msg.id} has already been sent into the cloud. Dropping injection."  if msg.id != nil

            out_id = 00000

            user_api.mdi.tools.protogen.protogen_encode(msg).each do |message|
              out_id = CC.indigen_next_id(message.asset)
              inject_hash = {
                "meta" => {
                  "account" =>     message.account,
                  "cookies" =>     message.cookies,
                  "class" => 'message'
                  },
                  "payload" => {
                  "id" =>          out_id,     # Indigen integer
                  "asset" =>       "ragent",
                  "sender" =>      send_channel,               # Sender identifier (can be the same as the asset)
                  "recipient" =>   "@@server@@",               # Recipient identifier (can be the same as the asset)
                  "type" =>        "message",
                  "received_at" => Time.now.to_i,               # timestamp integer in seconds
                  "channel" =>     channel,
                  "payload" =>     message.content,
                  "parent_id" =>   nil,                    # nil | message_identifier
                  "timeout" =>     0                       # -1 | 0 | timeout integer. 0 -> instant
                }
              }

              inject_hash['meta'].delete_if { |k, v| v.nil? }
              inject_hash['payload'].delete_if { |k, v| v.nil? }

              # todo: put some limitation
              CC.push(inject_hash,'messages')
            end

            # success !
            PUNK.end('injectmsg','ok','out',"SERVER <- SERVER MSG[#{crop_ref(out_id,4)}]")

            SDK_STATS.stats['agents'][user_api.user_class.agent_name]['inject_to_cloud'] += 1
            SDK_STATS.stats['agents'][user_api.user_class.agent_name]['total_sent'] += 1
            return true
          rescue Exception => e
            user_api.mdi.tools.log.error("Error on inject message")
            user_api.mdi.tools.print_ruby_exception(e)
            PUNK.end('injectmsg','ko','out',"SERVER <- SERVER MSG")
            # stats:
            SDK_STATS.stats['agents'][user_api.user_class.agent_name]['err_on_inject'] += 1
            SDK_STATS.stats['agents'][user_api.user_class.agent_name]['total_error'] += 1
            return false
          end
        end

        # Inject a track in the server queue (ie push a track to the server)
        # @return true on success
        # @param [TrackClass] track the track to send
        # @example Injecte a new track to the cloud
        #   new_track = user_api.mdi.dialog.create_new_track
        #   new_track.recorded_at = Time.now.to_i
        #   new_track.latitude = 4878384 # in degree * 10^-5
        #   new_track.longitude =  236682 # in degree * 10^-5
        #   new_track.asset = "3735843415387632"
        #   new_track.account = "my_account"
        #   new_track.set_field("MDI_CC_LEGAL_SPEED", "50")
        #   user_api.mdi.dialog.cloud_gate.inject_track(new_track)
        def inject_track(track)
          raise "Track id #{track.id} has already been sent into the cloud. Dropping injection."  if track.id != nil
          raise "I don't push empty track. Dropping injection." if track.fields_data.size == 0

          begin
            PUNK.start('injecttrack','inject track to cloud ...')


            # todo: put some limitation
            CC.push(track.to_hash_to_send_to_cloud,'tracks')

            # success !
            PUNK.end('injecttrack','ok','out',"SERVER <- SERVER TRACK")

            SDK_STATS.stats['agents'][user_api.user_class.agent_name]['inject_to_cloud'] += 1
            return true
          rescue Exception => e
            user_api.mdi.tools.log.error("Error on inject track")
            user_api.mdi.tools.print_ruby_exception(e)
            PUNK.end('injecttrack','ko','out',"SERVER <- SERVER TRACK")
            # stats:
            SDK_STATS.stats['agents'][user_api.user_class.agent_name]['err_on_inject'] += 1
            SDK_STATS.stats['agents'][user_api.user_class.agent_name]['total_error'] += 1
            return false
          end
        end


        # Inject a collection in the server queue (ie push a track to the server)
        # @return true on success
        # @param [CollectionClass] track the track to send
        def inject_collection(collection)
          raise "Collection has already been sent into the cloud. Dropping injection."  if collection.id != nil
          raise "I don't push empty collection. Dropping injection." if collection.data.size == 0

          begin
            PUNK.start('injectcollection','inject collection to cloud ...')


            # now push all elements of the collection
            collection.data.each do |el|
              if el.id == nil
                CC.logger.info("Injection #{el.class} of collection")
                case "#{el.class}"
                when "UserApis::Mdi::Dialog::PresenceClass"
                  user_api.mdi.dialog.cloud_gate.inject_presence(el)
                when "UserApis::Mdi::Dialog::MessageClass"
                  user_api.mdi.dialog.cloud_gate.inject_message(el, el.channel) # channel is good ? no idea !
                when "UserApis::Mdi::Dialog::TrackClass"
                  user_api.mdi.dialog.cloud_gate.inject_track(el)
                end
              end
            end

            # todo: put some limitation
            CC.push(collection.to_hash,'collections')


            # success !
            PUNK.end('injectcollection','ok','out',"SERVER <- SERVER COLLECTION")

            SDK_STATS.stats['agents'][user_api.user_class.agent_name]['inject_to_cloud'] += 1
            return true
          rescue Exception => e
            user_api.mdi.tools.log.error("Error on inject collection")
            user_api.mdi.tools.print_ruby_exception(e)
            PUNK.end('injectcollection','ko','out',"SERVER <- SERVER COLLECTION")
            # stats:
            SDK_STATS.stats['agents'][user_api.user_class.agent_name]['err_on_inject'] += 1
            SDK_STATS.stats['agents'][user_api.user_class.agent_name]['total_error'] += 1
            return false
          end
        end

      end
    end
  end
end