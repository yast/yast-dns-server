require "yast"
Yast.import "Service"
Yast.import "UI"

module UI
  class SrvStatusComponent
    include Yast::UIShortcuts
    include Yast::I18n
    include Yast::Logger

    def initialize(service_name, save_button_callback: nil)
      @service_name = service_name
      @save_button_callback = save_button_callback

      @after_save_action = :nothing
      @id_prefix = "_srv_status_#{@service_name}"
    end

    def widget
      VBox(
        ReplacePoint(Id(id_prefix),
          status_widget
        ),
        VSpacing(1),
        Right(
          PushButton(Id("#{id_prefix}_apply"), _("Save settings now without closing"))
        )
      )
    end

    def handle_input(input)
      case input
        when "#{id_prefix}_stop"
          stop_service
          refresh_widget
        when "#{id_prefix}_start"
          start_service
          refresh_widget
        when "#{id_prefix}_apply"
          @save_button_callback.call if @save_button_callback
          refresh_widget
        when /^#{id_prefix}_as_(.*)/
          @after_save_action = $1.to_sym
      end
    end

    def adjust_service_status
      return unless @after_save_action
      return if @after_save_action == :nothing
      send(:"#{@after_save_action}_service")
    end

    def refresh_widget
      Yast::UI.ReplaceWidget(Id(id_prefix), status_widget)
    end


    protected

    attr_reader :id_prefix

    # Should be redefined by services not following standard procedures
    def service_running?
      Yast::Service.active?(@service_name)
    end

    # Should be redefined by services not following standard procedures
    def start_service
      log.info "Default implementation of SrvStatusComponent#start for #{@service_name}"
      ret = Yast::Service.Start(@service_name)
      if ret && @after_save_action == :start
        @after_save_action = :reload
      end
      ret
    end

    # Should be redefined by services not following standard procedures
    def stop_service
      log.info "Default implementation of SrvStatusComponent#stop for #{@service_name}"
      ret = Yast::Service.Stop(@service_name)
      if ret && @after_save_action == :stop
        @after_save_action = :nothing
      end
      ret
    end

    # Should be redefined by services not following standard procedures
    def reload_service
      log.info "Default implementation of SrvStatusComponent#reload for #{@service_name}"
      Yast::Service.Reload(@service_name)
    end

    def status_widget
      VBox(
        Left(
          HBox(
            Label(_("Current status:")),
            Label(" "),
            *label_and_action_widgets
          )
        ),
        VSpacing(1),
        Left(Label(_("After saving settings:"))),
        RadioButtonGroup(
          VBox(
            *after_save_widgets
          )
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

    def after_save_widgets
      widgets = [
        Left(
          RadioButton(
            Id("#{id_prefix}_as_nothing"),
            Opt(:notify),
            "Do nothing",
            @after_save_action == :nothing
          )
        )
      ]
      if service_running?
        widgets << Left(
          RadioButton(
            Id("#{id_prefix}_as_reload"),
            Opt(:notify),
            "Reload/restart the service",
            @after_save_action == :reload
          )
        )
        widgets << Left(
          RadioButton(
            Id("#{id_prefix}_as_stop"),
            Opt(:notify),
            "Stop the service",
            @after_save_action == :stop
          )
        )
      else
        widgets << Left(
          RadioButton(
            Id("#{id_prefix}_as_start"),
            Opt(:notify),
            "Start the service",
            @after_save_action == :start
          )
        )
        widgets << VSpacing(1)
      end
      widgets
    end
  end
end
