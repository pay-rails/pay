Dir[File.join(__dir__, "webhooks", "**", "*.rb")].sort.each { |file| require file }
