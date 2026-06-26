# :nodoc:
module Bai::Provider
  def self.request_command(query : String, options : Bai::RequestOptions) : Bai::GenerationResult
    config = Bai::ApiConfig.resolve

    case config.api_type
    when "anthropic"
      Bai::AnthropicClient.request_command(config, query, options)
    when "openai_responses"
      Bai::OpenAIClient.request_command(config, query, options)
    when "openai_chat"
      Bai::OpenAIChatClient.request_command(config, query, options)
    else
      raise "unsupported API type: #{config.api_type}"
    end
  end

  def self.current : String
    Bai::ApiConfig.current_provider
  end
end
