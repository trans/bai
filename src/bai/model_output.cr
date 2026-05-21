# :nodoc:
module Bai::ModelOutput
  def self.parse(text : String, options : Bai::RequestOptions) : Bai::GenerationResult
    sanitized = sanitize_command(text)

    unless options.explain || options.strict
      return Bai::GenerationResult.new(sanitized)
    end

    json = JSON.parse(sanitized)
    command = json["command"]?.try(&.as_s?).to_s.strip
    explanation = json["explanation"]?.try(&.as_s?).try(&.strip)
    explanation = nil if explanation.try(&.empty?)

    command = sanitize_command(command)
    if command.empty? && explanation.nil?
      raise "structured response missing command and explanation"
    end

    Bai::GenerationResult.new(command, explanation)
  rescue ex : JSON::ParseException
    raise "model response was not valid JSON: #{ex.message}"
  end

  private def self.sanitize_command(text : String) : String
    s = text.strip
    if s.starts_with?("```")
      s = s.sub(/\A```[^\n]*\n?/, "").sub(/\n?```\z/, "")
    end
    s.strip
  end
end
