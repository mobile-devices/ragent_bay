#########################################################
# Xavier Demompion : xavier.demompion@mobile-devices.fr
# Mobile Devices 2013
#########################################################

require 'rubygems'
require 'rufus/scheduler'
require 'json'

module Rufus


  def self.run(crons)
    RAGENT.api.mdi.tools.log.info("Rufus run start")
    scheduler = Rufus::Scheduler.new

    crons.each do |k, v|
      p "Rufus init agent #{k}"
      RAGENT.api.mdi.tools.log.info("Rufus init cron tasks for agent #{k}")

      v.each do |cron_s|
        cron = JSON.parse(cron_s)
        RAGENT.api.mdi.tools.log.info("Adding cron task #{cron}")
        scheduler.cron cron['cron_schedule'] do
          RAGENT.api.mdi.tools.log.info("Rufus calling order #{cron['order']}")
          RIM.handle_order(JSON.parse(cron['order']))
        end
      end
    end
    true
  end

end
