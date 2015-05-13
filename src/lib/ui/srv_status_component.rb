require "yast"
Yast.import "Service"
Yast.import "UI"

module UI
  class SrvStatusComponent
    include Yast::UIShortcuts
    include Yast::I18n
    include Yast::Logger

    def initialize(service_name, reload: true, reload_callback: nil, enabled_callback: nil)
      @service_name = service_name
      @reload = reload
      @reload_callback = reload_callback
      @enabled_callback = enabled_callback

      @enabled = service_enabled?
      @id_prefix = "_srv_status_#{@service_name}"
    end

    def widget
      VBox(
        ReplacePoint(Id("#{id_prefix}_status"), HBox()),
        VSpacing(),
        on_boot_widget,
        VSpacing(),
        reload_widget
      )
    end

    def handle_input(input)
      case input
        when "#{id_prefix}_stop"
          stop_service
          update_widget
        when "#{id_prefix}_start"
          start_service
          update_widget
        when "#{id_prefix}_reload"
          @reload = Yast::UI.QueryWidget(Id(input), :Value)
	  @reload_callback.call(@reload) if @reload_callback
        when "#{id_prefix}_enabled"
          @enabled = Yast::UI.QueryWidget(Id(input), :Value)
	  @enabled_callback.call(@enabled) if @enabled_callback
      end
    end

    def update_widget
      Yast::UI.ChangeWidget(Id("#{id_prefix}_reload"), :Enabled, service_running?)
      Yast::UI.ChangeWidget(Id("#{id_prefix}_reload"), :Value, @reload)
      Yast::UI.ChangeWidget(Id("#{id_prefix}_enabled"), :Value, @enabled)
      Yast::UI.ReplaceWidget(Id("#{id_prefix}_status"), status_widget)
    end

    # Adjusts the current status only
    def adjust_status
      reload_service if service_running? && @reload
    end

    # Adjusts both the current status and the status on boot
    def adjust_service
      @enabled ? enable_service : disable_service
      adjust_service_status
    end

    # Checks if the user decided to enable the service on boot
    def enabled?
      @enabled
    end

    # Checks if the user decided to reload the service after saving
    def reload?
      @reload
    end

    protected

    attr_reader :id_prefix

    # Should be redefined by services not following standard procedures
    def service_running?
      Yast::Service.active?(@service_name)
    end

    # Should be redefined by services not following standard procedures
    def service_enabled?
      Yast::Service.enabled?(@service_name)
    end

    # Should be redefined by services not following standard procedures
    def start_service
      log.info "Default implementation of SrvStatusComponent#start_service for #{@service_name}"
      Yast::Service.Start(@service_name)
    end

    # Should be redefined by services not following standard procedures
    def stop_service
      log.info "Default implementation of SrvStatusComponent#stop_service for #{@service_name}"
      Yast::Service.Stop(@service_name)
    end

    # Should be redefined by services not following standard procedures
    def reload_service
      log.info "Default implementation of SrvStatusComponent#reload_service for #{@service_name}"
      Yast::Service.Reload(@service_name)
    end

    # Should be redefined by services not following standard procedures
    def enable_service
      log.info "Default implementation of SrvStatusComponent#enable_service for #{@service_name}"
      Yast::Service.Enable(@service_name)
    end

    # Should be redefined by services not following standard procedures
    def disable_service
      log.info "Default implementation of SrvStatusComponent#disable_service for #{@service_name}"
      Yast::Service.Disable(@service_name)
    end

    def status_widget
      Left(
        HBox(
          Label(_("Current status:")),
          Label(" "),
          *label_and_action_widgets
        )
      )
    end

    def on_boot_widget
      Left(
        CheckBox(
          Id("#{id_prefix}_enabled"),
          Opt(:notify),
          _("Start service during boot"),
        )
      )
    end

    def reload_widget
      Left(
        CheckBox(
          Id("#{id_prefix}_reload"),
          Opt(:notify),
          _("Reload/restart the service after saving settings"),
        )
      )
    end

    def label_and_action_widgets
      if service_running?
        [
          # TRANSLATORS: status of a service
          Label(_("running")),
          Label(" "),
          PushButton(Id("#{id_prefix}_stop"), _("Stop now"))
        ]
      else
        [
          # TRANSLATORS: status of a service
          Label(_("stopped")),
          Label(" "),
          PushButton(Id("#{id_prefix}_start"), _("Start now"))
        ]
      end
    end
  end
end
