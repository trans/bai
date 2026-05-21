# :nodoc:
module Bai::AnthropicClient
  def self.request_command(api_key : String, query : String) : String
    body = {
      model:      Bai::MODEL,
      max_tokens: Bai::MAX_TOKENS,
      system:     Bai::Prompt.system,
      messages:   [{role: "user", content: Bai::Prompt.user_message(query)}],
    }.to_json

    headers = HTTP::Headers{
      "x-api-key"         => api_key,
      "anthropic-version" => Bai::API_VER,
      "content-type"      => "application/json",
    }

    resp = HTTP::Client.post(Bai::API_URL, headers: headers, body: body)
    unless resp.success?
      raise "API error #{resp.status_code}: #{resp.body}"
    end

    extract_command(resp.body)
  end

  def self.extract_command(response_body : String) : String
    json = JSON.parse(response_body)
    blocks = json["content"]?.try(&.as_a?) || raise "API response missing content array"

    blocks.each do |block|
      next unless block_hash = block.as_h?

      type = block_hash["type"]?.try(&.as_s?)
      text = block_hash["text"]?.try(&.as_s?)
      next unless text
      next unless type.nil? || type == "text"

      sanitized = sanitize(text)
      return sanitized unless sanitized.empty?
    end

    raise "API response contained no usable text content"
  rescue ex : JSON::ParseException
    raise "API response was not valid JSON: #{ex.message}"
  end

  private def self.sanitize(text : String) : String
    s = text.strip
    if s.starts_with?("```")
      s = s.sub(/\A```[^\n]*\n?/, "").sub(/\n?```\z/, "")
    end
    s.strip
  end
end
