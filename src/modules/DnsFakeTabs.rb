# encoding: utf-8

# Dirty hack for tabs in YCP until the widget implementation is ready
require "yast"

module Yast
  class DnsFakeTabsClass < Module
    def DumbTabs(items, contents)
      items = deep_copy(items)
      contents = deep_copy(contents)
      tabs = HBox()

      Builtins.foreach(items) do |item|
        text = Ops.get_string(item, 1, "")
        idTerm = Ops.get_term(item, 0) { Id(:unknown) }
        tabs = Builtins.add(tabs, PushButton(idTerm, text))
      end

      tabs = Builtins.add(tabs, HStretch())

      Builtins.y2milestone("Creating tabs: %1", tabs)

      VBox(tabs, Frame("", contents))
    end

    publish :function => :DumbTabs, :type => "term (list <term>, term)"
  end

  DnsFakeTabs = DnsFakeTabsClass.new
end
