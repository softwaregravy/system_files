IRB.conf[:USE_AUTOCOMPLETE] = false
IRB.conf[:PAGER] = nil
IRB.conf[:SAVE_HISTORY] = 10000
IRB.conf[:HISTORY_FILE] = "#{ENV['HOME']}/.irb_history"

if defined?(Rails)
  include Rails.application.routes.url_helpers
  def r
    reload!
  end
end

