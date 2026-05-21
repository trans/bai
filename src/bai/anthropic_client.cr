# :nodoc:
module Bai::AnthropicClient
  def self.request_command(api_key : String, query : String) : String
    user_msg = String.build do |s|
      s << Bai::Prompt.user_message(query)
    end

    body = {
      model:      Bai::MODEL,
      max_tokens: Bai::MAX_TOKENS,
      system:     Bai::Prompt.system,
      messages:   [{role: "user", content: user_msg}],
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

    json = JSON.parse(resp.body)
    text = json["content"].as_a.first["text"].as_s
    sanitize(text)
  end

  private def self.sanitize(text : String) : String
    s = text.strip
    if s.starts_with?("```")
      s = s.sub(/\A```[^\n]*\n?/, "").sub(/\n?```\z/, "")
    end
    s.strip
  end
end
