#########################################################
# Xavier Demompion : xavier.demompion@mobile-devices.fr
# Mobile Devices 2013
#########################################################


module UserApis
  module Mdi
    module Dialog

      # @api public
      # This class handles outgoing communications from the cloud.
      class DeviceGateClass

        # @api private
        # @param channel [String] the messages passing through this gate will be sent on this channel
        def initialize(apis, default_send_channel)
          @user_apis = apis
          @default_send_channel = default_send_channel
        end

        # @api private
        def user_api
          @user_apis
        end

        # Push a message to the device.
        # @return true on success
        # @param asset [Fixnum] the asset the message will be sent to
        # @param account [String] account name to use
        # @param content [String] content of the message.
        # @example
        #    user_api.mdi.dialog.device_gate.push('fake_asset','fake_acount','my fake message')
        def push(asset, account, content, channel = @default_send_channel)
          begin
            PUNK.start('push','pushing msg ...')

            msg = user_api.mdi.dialog.create_new_message({
              'meta' => {
                'account' => account
                },
              'payload' => {
                'id' => CC.indigen_next_id(asset),
                'type' => 'message',
                'sender' => '@@server@@',
                'recipient' => asset,
                'channel' =>  channel,
                'payload' => content,
                'asset' => asset
              }
            })
            if RAGENT.running_env_name == 'sdk-vm'
              TestsHelper.message_sent(msg)
            end
            user_api.mdi.tools.protogen.protogen_encode(msg).each {|message| message.push}
            # success !
            PUNK.end('push','ok','out',"SERVER -> MSG[#{crop_ref(msg.id,4)}]")


            SDK_STATS.stats['agents'][user_api.user_class.agent_name]['push_sent_to_device'] += 1
            SDK_STATS.stats['agents'][user_api.user_class.agent_name]['total_sent'] += 1
            return true
          rescue Exception => e
            user_api.mdi.tools.log.error("Error on push")
            user_api.mdi.tools.print_ruby_exception(e)
            PUNK.end('push','ko','out',"SERVER -> MSG")
            # stats:
            SDK_STATS.stats['agents'][user_api.user_class.agent_name]['err_on_push'] += 1
            SDK_STATS.stats['agents'][user_api.user_class.agent_name]['total_error'] += 1
            return false
          end
        end

        # Reply to a device message. The device has a different behaviour is the message is a reply to another one.
        # @return the replied message on success, nil instead
        # @param msg [CloudConnectServices::Message] message to reply to
        # @param content [Object] content of the message
        # @param cookies [String] optional cookies, reseverd for Protogen (see the Protogen guide). You should not need to use this parameter in your agent code.
        # @example
        #     replied_msg = user_api.mdi.dialog.device_gate.reply(msg, msg.content)
        def reply(of_msg, content, cookies = nil)
          begin
            PUNK.start('reply','replying msg ...')
            response = of_msg.clone
            response.parent_id = of_msg.id
            response.id = CC.indigen_next_id(response.asset)
            response.content = content
            response.meta['protogen_cookies'] = cookies
            response.sender = '@@server@@'
            response.recipient = of_msg.asset
            user_api.mdi.tools.protogen.protogen_encode(response).each {|message| message.push}
            # success !
            PUNK.end('reply','ok','out',"SERVER -> MSG[#{crop_ref(response.id,4)}] [reply of #{crop_ref(of_msg.id,4)}]")
            # stats:
            SDK_STATS.stats['agents'][user_api.user_class.agent_name]['reply_sent_to_device'] += 1
            SDK_STATS.stats['agents'][user_api.user_class.agent_name]['total_sent'] += 1
            return response
          rescue Exception => e
            user_api.mdi.tools.log.error("Error on reply")
            user_api.mdi.tools.print_ruby_exception(e)
            PUNK.end('reply','ko','out',"SERVER -> MSG (reply)")
            # stats:
            SDK_STATS.stats['agents'][user_api.user_class.agent_name]['err_on_reply'] += 1
            SDK_STATS.stats['agents'][user_api.user_class.agent_name]['total_error'] += 1
            return false
          end
        end

      end

    end
  end
end
