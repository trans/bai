require "http/client"
require "json"
require "option_parser"

# `Bai` exposes the CLI entry logic for the executable and for tests.
module Bai
  # The current released version of the CLI.
  VERSION = "0.2.0"

  # :nodoc:
  API_URL    = "https://api.anthropic.com/v1/messages"
  # :nodoc:
  API_VER    = "2023-06-01"
  # :nodoc:
  MODEL      = ENV["BAI_MODEL"]? || "claude-haiku-4-5-20251001"
  # :nodoc:
  MAX_TOKENS = 512

  # :nodoc:
  SYSTEM = <<-PROMPT
    You translate a natural-language request into a single shell command for the user's current shell.
    Output ONLY the command itself. No markdown fences, no prose, no leading $, no trailing newline.
    Prefer a single line. Match the user's shell syntax (fish vs. bash/zsh) when it matters.
    If the request is ambiguous or unsafe, output the safest reasonable interpretation.
    PROMPT

  # Parses CLI arguments and prints either help text, a dry-run prompt preview,
  # or the proposed shell command.
  #
  # The query is read from `argv` first and falls back to stdin when piped input
  # is available. Returns `0` on success, `1` on runtime or API failures, and
  # `2` when no query was provided.
  def self.run(argv : Array(String)) : Int32
    show_help = false
    dry_run = false
    copy_override : Bool? = nil

    parser = OptionParser.new do |p|
      p.banner = "Usage: bai [options] [--] <natural language query>"
      p.on("-h", "--help", "Show help") { show_help = true }
      p.on("-v", "--version", "Show version") { puts VERSION; exit 0 }
      p.on("-n", "--dry-run", "Print what would be sent to the model and exit (no API call)") { dry_run = true }
      p.on("--copy", "Copy result to clipboard (default if a clipboard tool is available)") { copy_override = true }
      p.on("--no-copy", "Do not copy result to clipboard") { copy_override = false }
    end
    parser.parse(argv)

    if show_help
      puts parser
      puts
      puts "Env vars:"
      puts "  ANTHROPIC_API_KEY    Required."
      puts "  BAI_MODEL            Override model (default: #{MODEL})."
      puts "  BAI_CLIPBOARD        Set to 0/off/false/no to disable clipboard."
      puts "  BAI_PROMPT_FILE      Override prompt addendum path (default: #{default_prompt_path || "~/.config/bai/prompt.md"})."
      return 0
    end

    query = argv.join(" ").strip
    query = STDIN.gets_to_end.strip if query.empty? && !STDIN.tty?
    if query.empty?
      STDERR.puts "bai: no query given"
      return 2
    end

    if dry_run
      print_dry_run(query)
      return 0
    end

    api_key = ENV["ANTHROPIC_API_KEY"]?
    unless api_key
      STDERR.puts "bai: ANTHROPIC_API_KEY not set"
      return 1
    end

    cmd = request_command(api_key, query)

    if clipboard_enabled?(copy_override)
      if copy_to_clipboard(cmd)
        STDERR.puts "bai: copied to clipboard" if STDERR.tty?
      end
    end

    print cmd
    0
  rescue ex
    STDERR.puts "bai: #{ex.message}"
    1
  end

  private def self.clipboard_enabled?(override : Bool?) : Bool
    return override unless override.nil?
    case ENV["BAI_CLIPBOARD"]?.try(&.downcase)
    when "0", "off", "false", "no" then false
    else                                true
    end
  end

  private def self.detect_clipboard_tool : Tuple(String, Array(String))?
    if ENV["WAYLAND_DISPLAY"]? && Process.find_executable("wl-copy")
      return {"wl-copy", [] of String}
    end
    if ENV["DISPLAY"]? && Process.find_executable("xclip")
      return {"xclip", ["-selection", "clipboard"]}
    end
    if Process.find_executable("pbcopy")
      return {"pbcopy", [] of String}
    end
    nil
  end

  private def self.copy_to_clipboard(text : String) : Bool
    tool = detect_clipboard_tool
    return false unless tool
    cmd, args = tool
    status = Process.run(cmd, args, input: IO::Memory.new(text))
    status.success?
  rescue
    false
  end

  private def self.request_command(api_key : String, query : String) : String
    user_msg = String.build do |s|
      s << gather_context
      s << "\nRequest: " << query
    end

    body = {
      model:      MODEL,
      max_tokens: MAX_TOKENS,
      system:     system_prompt,
      messages:   [{role: "user", content: user_msg}],
    }.to_json

    headers = HTTP::Headers{
      "x-api-key"         => api_key,
      "anthropic-version" => API_VER,
      "content-type"      => "application/json",
    }

    resp = HTTP::Client.post(API_URL, headers: headers, body: body)
    unless resp.success?
      raise "API error #{resp.status_code}: #{resp.body}"
    end

    json = JSON.parse(resp.body)
    text = json["content"].as_a.first["text"].as_s
    sanitize(text)
  end

  private def self.print_dry_run(query : String)
    puts "model: #{MODEL}"
    puts
    puts "--- system ---"
    puts system_prompt
    puts "--- user ---"
    print gather_context
    puts "Request: #{query}"
  end

  private def self.system_prompt : String
    addendum = load_addendum
    return SYSTEM if addendum.empty?
    "#{SYSTEM}\n\nUser preferences:\n#{addendum}"
  end

  private def self.load_addendum : String
    path = ENV["BAI_PROMPT_FILE"]? || default_prompt_path
    return "" unless path && File.exists?(path)
    File.read(path).strip
  rescue
    ""
  end

  private def self.default_prompt_path : String?
    home = ENV["HOME"]?
    return nil unless home
    base = ENV["XDG_CONFIG_HOME"]? || "#{home}/.config"
    "#{base}/bai/prompt.md"
  end

  private def self.gather_context : String
    String.build do |s|
      s << "OS: " << os_pretty_name << "\n"
      s << "Kernel: " << uname("-r") << "\n"
      s << "Arch: " << uname("-m") << "\n"
      s << "Shell: " << shell_name << "\n"
      s << "CWD: " << (Dir.current rescue "?") << "\n"
      s << "HOME: " << (ENV["HOME"]? || "?") << "\n"
      s << "Editor: " << (ENV["EDITOR"]? || ENV["VISUAL"]? || "unset") << "\n"
    end
  end

  private def self.os_pretty_name : String
    if File.exists?("/etc/os-release") && File::Info.readable?("/etc/os-release")
      File.each_line("/etc/os-release") do |line|
        if line.starts_with?("PRETTY_NAME=")
          return line.split('=', 2)[1].strip.strip('"')
        end
      end
    end
    uname("-sr")
  rescue
    "unknown"
  end

  private def self.uname(flag : String) : String
    io = IO::Memory.new
    Process.run("uname", [flag], output: io)
    io.to_s.strip
  rescue
    "unknown"
  end

  private def self.shell_name : String
    parent_shell_name || ENV["SHELL"]?.try(&.split('/').last) || "sh"
  end

  private def self.parent_shell_name : String?
    name = read_proc_comm(Process.ppid) || read_ps_comm(Process.ppid)
    return nil unless name
    cleaned = name.lstrip('-').split('/').last
    known_shell_names.includes?(cleaned) ? cleaned : nil
  end

  private def self.known_shell_names : Array(String)
    %w[fish zsh bash sh dash ash ksh tcsh csh nu xonsh elvish]
  end

  private def self.read_proc_comm(pid : Int) : String?
    path = "/proc/#{pid}/comm"
    return nil unless File.exists?(path)
    File.read(path).strip
  rescue
    nil
  end

  private def self.read_ps_comm(pid : Int) : String?
    io = IO::Memory.new
    status = Process.run("ps", ["-o", "comm=", "-p", pid.to_s], output: io)
    return nil unless status.success?
    result = io.to_s.strip
    result.empty? ? nil : result
  rescue
    nil
  end

  private def self.sanitize(text : String) : String
    s = text.strip
    if s.starts_with?("```")
      s = s.sub(/\A```[^\n]*\n?/, "").sub(/\n?```\z/, "")
    end
    s.strip
  end
end
