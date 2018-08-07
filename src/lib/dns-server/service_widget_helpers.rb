# encoding: utf-8

# Copyright (c) [2018] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.
# encoding: utf-8

require "cwm/service_widget"
require "yast2/system_service"

module Y2DnsServer
  module ServiceWidgetHelpers
    # Returns the 'named' system service
    #
    # @return [Yast2::SystemService] 'named' system service
    def service
      @service ||= Yast2::SystemService.find("named")
    end

    # Widget to define status and start mode of the service
    #
    # @return [CWM::ServiceWidget]
    #
    # @see #service
    def service_widget
      @service_widget ||= CWM::ServiceWidget.new(service)
    end
  end
end
