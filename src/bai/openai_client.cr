# :nodoc:
module Bai::OpenAIClient
  API_URL = "https://api.openai.com/v1/responses"
  MODEL   = Bai::Config.value("BAI_OPENAI_MODEL") || "gpt-5-mini"

  def self.request_command(api_key : String, query : String, options : Bai::RequestOptions) : Bai::GenerationResult
    body = {
      model:        MODEL,
      instructions: Bai::Prompt.system(options),
      input:        Bai::Prompt.user_message(query, options.shell_override),
    }.to_json

    headers = HTTP::Headers{
      "authorization" => "Bearer #{api_key}",
      "content-type"  => "application/json",
    }

    resp = HTTP::Client.post(API_URL, headers: headers, body: body)
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

    if output_text = json["output_text"]?.try(&.as_s?)
      return Bai::ModelOutput.parse(output_text, options)
    end

    outputs = json["output"]?.try(&.as_a?) || raise "API response missing output array"

    outputs.each do |item|
      next unless item_hash = item.as_h?
      next unless item_hash["type"]?.try(&.as_s?) == "message"

      content = item_hash["content"]?.try(&.as_a?)
      next unless content

      content.each do |block|
        next unless block_hash = block.as_h?
        next unless block_hash["type"]?.try(&.as_s?) == "output_text"

        text = block_hash["text"]?.try(&.as_s?)
        next unless text

        result = Bai::ModelOutput.parse(text, options)
        return result unless result.command.empty? && result.explanation.nil?
      end
    end

    raise "API response contained no usable output text"
  rescue ex : JSON::ParseException
    raise "API response was not valid JSON: #{ex.message}"
  end
end
