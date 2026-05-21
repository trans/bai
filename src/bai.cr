require "http/client"
require "json"
require "option_parser"
require "./bai/anthropic_client"
require "./bai/clipboard"
require "./bai/config"
require "./bai/model_output"
require "./bai/prompt"
require "./bai/provider"
require "./bai/openai_client"
require "./bai/system_context"
require "./bai/types"

# `Bai` exposes the CLI entry logic for the executable and for tests.
module Bai
  # The current released version of the CLI.
  VERSION = "0.3.1"

  # :nodoc:
  API_URL    = "https://api.anthropic.com/v1/messages"
  # :nodoc:
  API_VER    = "2023-06-01"
  # :nodoc:
  MODEL      = Config.value("BAI_ANTHROPIC_MODEL", legacy: "BAI_MODEL") || "claude-haiku-4-5-20251001"
  # :nodoc:
  MAX_TOKENS = 512

  # Parses CLI arguments and prints either help text, a dry-run prompt preview,
  # or the proposed shell command.
  #
  # The query is read from `argv` first and falls back to stdin when piped input
  # is available. Returns `0` on success, `1` on runtime or API failures, and
  # `2` when no query was provided.
  def self.run(
    argv : Array(String),
    stdin : IO = STDIN,
    stdout : IO = STDOUT,
    stderr : IO = STDERR,
    stdin_tty : Bool = STDIN.tty?,
    command_requester : Proc(String, RequestOptions, GenerationResult)? = nil,
    clipboard_copier : Proc(String, Bool)? = nil
  ) : Int32
    show_help = false
    show_version = false
    show_config = false
    explain = false
    json_output = false
    strict = false
    dry_run = false
    copy_override : Bool? = nil
    shell_override : String? = nil

    parser = OptionParser.new do |p|
      p.banner = "Usage: bai [options] [--] <natural language query>"
      p.on("-h", "--help", "Show help") { show_help = true }
      p.on("-v", "--version", "Show version") { show_version = true }
      p.on("--explain", "Print a brief explanation to stderr") { explain = true }
      p.on("--json", "Print machine-readable JSON to stdout") { json_output = true }
      p.on("--strict", "Refuse ambiguous or unsafe requests instead of guessing") { strict = true }
      p.on("-n", "--dry-run", "Print what would be sent to the model and exit (no API call)") { dry_run = true }
      p.on("--show-config", "Print effective configuration and exit") { show_config = true }
      p.on("--shell SHELL", "Force shell context (fish, bash, zsh, sh, dash, ash, ksh, tcsh, csh, nu, xonsh, elvish)") { |value| shell_override = value }
      p.on("--copy", "Copy result to clipboard (default if a clipboard tool is available)") { copy_override = true }
      p.on("--no-copy", "Do not copy result to clipboard") { copy_override = false }
    end
    parser.parse(argv)

    if show_help
      print_help(parser, stdout)
      return 0
    end

    if show_version
      stdout.puts VERSION
      return 0
    end

    if show_config
      print_config(stdout, shell_override)
      return 0
    end

    options = RequestOptions.new(explain: explain, json: json_output, strict: strict, shell_override: shell_override)

    query = argv.join(" ").strip
    query = stdin.gets_to_end.strip if query.empty? && !stdin_tty
    if query.empty?
      stderr.puts "bai: no query given"
      return 2
    end

    if dry_run
      print_dry_run(query, stdout, options)
      return 0
    end

    result = if command_requester
               command_requester.call(query, options)
             else
               Provider.request_command(query, options)
             end

    if result.command.empty?
      print_failure(stdout, stderr, result, options)
      return 1
    end

    if options.json
      stdout.print serialize_result(result, options)
      return 0
    end

    if explain && result.explanation
      stderr.puts "why: #{result.explanation}"
    end

    if Clipboard.enabled?(copy_override)
      copied = if clipboard_copier
                 clipboard_copier.call(result.command)
               else
                 Clipboard.copy(result.command)
               end
      if copied
        stderr.puts "bai: copied to clipboard" if stderr.tty?
      end
    end

    stdout.print result.command
    0
  rescue ex
    stderr.puts "bai: #{ex.message}"
    1
  end

  private def self.print_help(parser : OptionParser, output : IO)
    output.puts parser
    output.puts
    output.puts "Env vars:"
    output.puts "  Env vars override matching files in #{Config.dir || "~/.config/bai"}."
    output.puts "  BAI_PROVIDER         Command model backend: anthropic or openai (default: anthropic)."
    output.puts "  ANTHROPIC_API_KEY    Required when BAI_PROVIDER=anthropic."
    output.puts "  OPENAI_API_KEY       Required when BAI_PROVIDER=openai."
    output.puts "  BAI_ANTHROPIC_MODEL  Override Anthropic model (preferred; legacy alias: BAI_MODEL)."
    output.puts "  BAI_MODEL            Legacy alias for BAI_ANTHROPIC_MODEL."
    output.puts "  BAI_OPENAI_MODEL     Override OpenAI model (default: #{OpenAIClient::MODEL})."
    output.puts "  BAI_SHELL            Override detected shell context."
    output.puts "  BAI_CLIPBOARD        Set to 0/off/false/no to disable clipboard."
    output.puts "  BAI_PROMPT_FILE      Override prompt addendum path (default: #{Prompt.default_addendum_path || "~/.config/bai/prompt.md"})."
  end

  private def self.print_config(output : IO, shell_override : String?)
    shell = SystemContext.shell_name(shell_override)

    output.puts "version: #{VERSION}"
    output.puts "config_dir: #{Config.dir || "unset"}"
    output.puts "provider: #{Provider.current}"
    output.puts "shell: #{shell}"
    output.puts "anthropic_model: #{MODEL}"
    output.puts "openai_model: #{OpenAIClient::MODEL}"
    output.puts "clipboard_enabled: #{Clipboard.enabled?(nil)}"
    output.puts "prompt_file: #{Prompt.effective_addendum_path || "unset"}"
    output.puts "anthropic_api_key: #{redacted(Bai::Config.value("ANTHROPIC_API_KEY"))}"
    output.puts "openai_api_key: #{redacted(Bai::Config.value("OPENAI_API_KEY"))}"
  end

  private def self.print_failure(stdout : IO, stderr : IO, result : GenerationResult, options : RequestOptions)
    if options.json
      stdout.print serialize_result(result, options)
    else
      stderr.puts "bai: #{result.explanation || "no command produced"}"
    end
  end

  private def self.print_dry_run(query : String, output : IO, options : RequestOptions)
    output.puts "model: #{MODEL}"
    output.puts
    output.puts "--- system ---"
    output.puts Prompt.system(options)
    output.puts "--- user ---"
    output.puts Prompt.user_message(query, options.shell_override)
  end

  private def self.redacted(value : String?) : String
    return "unset" unless value
    return "[set]" if value.size <= 8
    "#{value[0, 4]}...#{value[-4, 4]}"
  end

  private def self.serialize_result(result : GenerationResult, options : RequestOptions) : String
    {
      command:     result.command,
      explanation: result.explanation,
      provider:    Provider.current,
      shell:       SystemContext.shell_name(options.shell_override),
      strict:      options.strict,
    }.to_json
  end
end
