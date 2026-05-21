# :nodoc:
module Bai::Prompt
  SYSTEM = <<-PROMPT
    You translate a natural-language request into a single shell command for the user's current shell.
    Output ONLY the command itself. No markdown fences, no prose, no leading $, no trailing newline.
    Prefer a single line. Match the user's shell syntax (fish vs. bash/zsh) when it matters.
    If the request is ambiguous or unsafe, output the safest reasonable interpretation.
    PROMPT

  def self.system(options : Bai::RequestOptions = Bai::RequestOptions.new) : String
    addendum = load_addendum
    base = addendum.empty? ? SYSTEM : "#{SYSTEM}\n\nUser preferences:\n#{addendum}"
    base + output_contract(options)
  end

  def self.user_message(query : String, shell_override : String? = nil) : String
    String.build do |s|
      s << Bai::SystemContext.gather(shell_override)
      s << "\nRequest: " << query
    end
  end

  def self.default_addendum_path : String?
    config_dir = Bai::Config.dir
    return nil unless config_dir
    "#{config_dir}/prompt.md"
  end

  def self.effective_addendum_path : String?
    Bai::Config.value("BAI_PROMPT_FILE") || default_addendum_path
  end

  private def self.load_addendum : String
    path = effective_addendum_path
    return "" unless path && File.exists?(path)
    File.read(path).strip
  rescue
    ""
  end

  private def self.output_contract(options : Bai::RequestOptions) : String
    return "" unless options.explain || options.strict

    strict_clause = if options.strict
                      %(\nIf the request is ambiguous, unsafe, or lacks enough information, return {"command":"","explanation":"..."} and do not guess.)
                    else
                      ""
                    end

    <<-PROMPT

      Return ONLY a JSON object with exactly these keys:
      {"command":"...","explanation":"..."}
      `command` must be a shell command string with no markdown fences and no leading `$`.
      `explanation` must be one brief sentence explaining the choice.#{strict_clause}
      PROMPT
  end
end
