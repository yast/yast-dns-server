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

    # Returns the status widget for service
    #
    # @return [::CWM::ServiceWidget] service status widget
    #
    # @see #service
    def service_widget
      @service_widget ||= ::CWM::ServiceWidget.new(service)
    end
  end
end
