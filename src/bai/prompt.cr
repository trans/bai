# :nodoc:
module Bai::Prompt
  SYSTEM = <<-PROMPT
    You translate a natural-language request into a single shell command for the user's current shell.
    Output ONLY the command itself. No markdown fences, no prose, no leading $, no trailing newline.
    Prefer a single line. Match the user's shell syntax (fish vs. bash/zsh) when it matters.
    If the request is ambiguous or unsafe, output the safest reasonable interpretation.
    PROMPT

  def self.system : String
    addendum = load_addendum
    return SYSTEM if addendum.empty?
    "#{SYSTEM}\n\nUser preferences:\n#{addendum}"
  end

  def self.user_message(query : String) : String
    String.build do |s|
      s << Bai::SystemContext.gather
      s << "\nRequest: " << query
    end
  end

  def self.default_addendum_path : String?
    home = ENV["HOME"]?
    return nil unless home
    base = ENV["XDG_CONFIG_HOME"]? || "#{home}/.config"
    "#{base}/bai/prompt.md"
  end

  private def self.load_addendum : String
    path = ENV["BAI_PROMPT_FILE"]? || default_addendum_path
    return "" unless path && File.exists?(path)
    File.read(path).strip
  rescue
    ""
  end
end
