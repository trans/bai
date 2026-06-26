# :nodoc:
module Bai::OpenAIChatClient
  def self.request_command(config : Bai::ApiConfig, query : String, options : Bai::RequestOptions) : Bai::GenerationResult
    body = {
      model:       config.model,
      temperature: 0,
      messages:    [
        {role: "system", content: Bai::Prompt.system(options)},
        {role: "user", content: Bai::Prompt.user_message(query, options.shell_override)},
      ],
    }.to_json

    headers = HTTP::Headers{
      "authorization" => "Bearer #{config.api_key!}",
      "content-type"  => "application/json",
    }

    resp = HTTP::Client.post(config.endpoint("/v1/chat/completions"), headers: headers, body: body)
    unless resp.success?
      raise "API error #{resp.status_code}: #{resp.body}"
    end

    extract_result(resp.body, options)
  end

  def self.extract_command(response_body : String) : String
    extract_result(response_body, Bai::RequestOptions.new).command
  end

  def self.extract_result(response_body : String, options : Bai::RequestOptions) : Bai::GenerationResult
    json = JSON.parse(response_body)
    choices = json["choices"]?.try(&.as_a?) || raise "API response missing choices array"

    choices.each do |choice|
      next unless choice_hash = choice.as_h?
      message = choice_hash["message"]?.try(&.as_h?)
      next unless message

      text = message["content"]?.try(&.as_s?)
      next unless text

      result = Bai::ModelOutput.parse(text, options)
      return result unless result.command.empty? && result.explanation.nil?
    end

    raise "API response contained no usable message content"
  rescue ex : JSON::ParseException
    raise "API response was not valid JSON: #{ex.message}"
  end
end
