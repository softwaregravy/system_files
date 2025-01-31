IRB.conf[:USE_AUTOCOMPLETE] = false
IRB.conf[:USE_PAGER] = false
IRB.conf[:SAVE_HISTORY] = 10000
IRB.conf[:HISTORY_FILE] = "#{ENV['HOME']}/.irb_history"
IRB.conf[:AUTO_INDENT] = true

if defined?(Rails)
  include Rails.application.routes.url_helpers
  def r
    reload!
  end
end

begin
  require 'amazing_print'
  AmazingPrint.irb!
rescue LoadError, NameError
end
