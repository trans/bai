# :nodoc:
module Bai::Provider
  def self.request_command(query : String) : String
    case current
    when "anthropic"
      api_key = ENV["ANTHROPIC_API_KEY"]? || raise "ANTHROPIC_API_KEY not set"
      Bai::AnthropicClient.request_command(api_key, query)
    when "openai"
      api_key = ENV["OPENAI_API_KEY"]? || raise "OPENAI_API_KEY not set"
      Bai::OpenAIClient.request_command(api_key, query)
    else
      raise "unsupported provider: #{current}"
    end
  end

  def self.current : String
    provider = ENV["BAI_PROVIDER"]?.try(&.downcase) || "anthropic"
    provider.empty? ? "anthropic" : provider
  end
end
