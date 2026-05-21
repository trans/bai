require "http/client"
require "json"
require "option_parser"
require "./bai/anthropic_client"
require "./bai/clipboard"
require "./bai/prompt"
require "./bai/provider"
require "./bai/openai_client"
require "./bai/system_context"

# `Bai` exposes the CLI entry logic for the executable and for tests.
module Bai
  # The current released version of the CLI.
  VERSION = "0.3.0"

  # :nodoc:
  API_URL    = "https://api.anthropic.com/v1/messages"
  # :nodoc:
  API_VER    = "2023-06-01"
  # :nodoc:
  MODEL      = ENV["BAI_ANTHROPIC_MODEL"]? || ENV["BAI_MODEL"]? || "claude-haiku-4-5-20251001"
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
    command_requester : Proc(String, String)? = nil,
    clipboard_copier : Proc(String, Bool)? = nil
  ) : Int32
    show_help = false
    show_version = false
    dry_run = false
    copy_override : Bool? = nil

    parser = OptionParser.new do |p|
      p.banner = "Usage: bai [options] [--] <natural language query>"
      p.on("-h", "--help", "Show help") { show_help = true }
      p.on("-v", "--version", "Show version") { show_version = true }
      p.on("-n", "--dry-run", "Print what would be sent to the model and exit (no API call)") { dry_run = true }
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

    query = argv.join(" ").strip
    query = stdin.gets_to_end.strip if query.empty? && !stdin_tty
    if query.empty?
      stderr.puts "bai: no query given"
      return 2
    end

    if dry_run
      print_dry_run(query, stdout)
      return 0
    end

    cmd = if command_requester
            command_requester.call(query)
          else
            Provider.request_command(query)
          end

    if Clipboard.enabled?(copy_override)
      copied = if clipboard_copier
                 clipboard_copier.call(cmd)
               else
                 Clipboard.copy(cmd)
               end
      if copied
        stderr.puts "bai: copied to clipboard" if stderr.tty?
      end
    end

    stdout.print cmd
    0
  rescue ex
    stderr.puts "bai: #{ex.message}"
    1
  end

  private def self.print_help(parser : OptionParser, output : IO)
    output.puts parser
    output.puts
    output.puts "Env vars:"
    output.puts "  BAI_PROVIDER         Command model backend: anthropic or openai (default: anthropic)."
    output.puts "  ANTHROPIC_API_KEY    Required when BAI_PROVIDER=anthropic."
    output.puts "  OPENAI_API_KEY       Required when BAI_PROVIDER=openai."
    output.puts "  BAI_ANTHROPIC_MODEL  Override Anthropic model (preferred; legacy alias: BAI_MODEL)."
    output.puts "  BAI_MODEL            Legacy alias for BAI_ANTHROPIC_MODEL."
    output.puts "  BAI_OPENAI_MODEL     Override OpenAI model (default: #{OpenAIClient::MODEL})."
    output.puts "  BAI_CLIPBOARD        Set to 0/off/false/no to disable clipboard."
    output.puts "  BAI_PROMPT_FILE      Override prompt addendum path (default: #{Prompt.default_addendum_path || "~/.config/bai/prompt.md"})."
  end

  private def self.print_dry_run(query : String, output : IO)
    output.puts "model: #{MODEL}"
    output.puts
    output.puts "--- system ---"
    output.puts Prompt.system
    output.puts "--- user ---"
    output.puts Prompt.user_message(query)
  end
end
