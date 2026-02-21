if ENV["LOG_JSON"] == "true"
  class JsonLogFormatter < Logger::Formatter
    def call(severity, time, progname, msg)
      payload = {
        level: severity,
        time: time.utc.iso8601(3),
        progname: progname,
        message: msg.is_a?(String) ? msg : msg.inspect
      }

      "#{payload.to_json}\n"
    end
  end

  Rails.application.config.log_formatter = JsonLogFormatter.new
end
