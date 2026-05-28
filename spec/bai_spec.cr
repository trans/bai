require "./spec_helper"

module BaiSpecSupport
  def self.with_env(key : String, value : String?)
    original = ENV[key]?

    if value.nil?
      ENV.delete(key)
    else
      ENV[key] = value
    end

    yield
  ensure
    if original.nil?
      ENV.delete(key)
    else
      ENV[key] = original
    end
  end

  def self.with_config(files : Hash(String, String))
    path = "/tmp/bai-spec-config-#{Process.pid}-#{Random.rand(1_000_000)}"
    Dir.mkdir_p(path)

    files.each do |name, value|
      File.write("#{path}/#{name}", value)
    end

    with_env("BAI_CONFIG_DIR", path) do
      yield path
    end
  ensure
    FileUtils.rm_r(path) if path && Dir.exists?(path)
  end
end

describe Bai do
  it "exposes a version string" do
    Bai::VERSION.should eq("0.4.2")
  end

  it "prints help to stdout" do
    stdout = IO::Memory.new
    stderr = IO::Memory.new

    Bai.run(["--help"], stdout: stdout, stderr: stderr).should eq(0)

    stdout.to_s.should contain("Usage: bai [options]")
    stdout.to_s.should contain("--explain")
    stdout.to_s.should contain("--json")
    stdout.to_s.should contain("--strict")
    stderr.to_s.should eq("")
  end

  it "prints the version without exiting the process" do
    stdout = IO::Memory.new
    stderr = IO::Memory.new

    Bai.run(["--version"], stdout: stdout, stderr: stderr).should eq(0)

    stdout.to_s.should eq("#{Bai::VERSION}\n")
    stderr.to_s.should eq("")
  end

  it "prints effective config without requiring a query" do
    BaiSpecSupport.with_env("BAI_PROVIDER", nil) do
      BaiSpecSupport.with_env("ANTHROPIC_API_KEY", nil) do
        BaiSpecSupport.with_config({
          "provider"           => "openai",
          "openai_api_key"     => "sk-openai-test-1234",
          "anthropic_api_key"  => "sk-ant-test-5678",
          "shell"              => "zsh",
        }) do
          stdout = IO::Memory.new
          stderr = IO::Memory.new

          Bai.run(["--show-config"], stdout: stdout, stderr: stderr).should eq(0)

          stdout.to_s.should contain("provider: openai")
          stdout.to_s.should contain("shell: zsh")
          stdout.to_s.should contain("anthropic_api_key: sk-a...5678")
          stdout.to_s.should contain("openai_api_key: sk-o...1234")
          stderr.to_s.should eq("")
        end
      end
    end
  end

  it "returns 2 when no query is given" do
    stdout = IO::Memory.new
    stderr = IO::Memory.new

    Bai.run([] of String, stdout: stdout, stderr: stderr).should eq(2)

    stdout.to_s.should eq("")
    stderr.to_s.should eq("bai: no query given\n")
  end

  it "prints dry-run prompt output without requiring an API key" do
    stdout = IO::Memory.new
    stderr = IO::Memory.new

    Bai.run(["--dry-run", "list", "files"], stdout: stdout, stderr: stderr).should eq(0)

    stdout.to_s.should contain("model: ")
    stdout.to_s.should contain("Request: list files")
    stderr.to_s.should eq("")
  end

  it "returns 1 when the API key is missing" do
    BaiSpecSupport.with_env("ANTHROPIC_API_KEY", nil) do
      stdout = IO::Memory.new
      stderr = IO::Memory.new

      Bai.run(["list", "files"], stdout: stdout, stderr: stderr).should eq(1)

      stdout.to_s.should eq("")
      stderr.to_s.should eq("bai: ANTHROPIC_API_KEY not set\n")
    end
  end

  it "returns 1 when the OpenAI API key is missing for the openai provider" do
    BaiSpecSupport.with_env("BAI_PROVIDER", "openai") do
      BaiSpecSupport.with_env("OPENAI_API_KEY", nil) do
        stdout = IO::Memory.new
        stderr = IO::Memory.new

        Bai.run(["list", "files"], stdout: stdout, stderr: stderr).should eq(1)

        stdout.to_s.should eq("")
        stderr.to_s.should eq("bai: OPENAI_API_KEY not set\n")
      end
    end
  end

  it "reads the provider from a config file when the env var is unset" do
    BaiSpecSupport.with_env("BAI_PROVIDER", nil) do
      BaiSpecSupport.with_config({"provider" => "openai"}) do
        Bai::Provider.current.should eq("openai")
      end
    end
  end

  it "uses a shell override in dry-run output" do
    stdout = IO::Memory.new
    stderr = IO::Memory.new

    Bai.run(["--dry-run", "--shell", "nu", "list", "files"], stdout: stdout, stderr: stderr).should eq(0)

    stdout.to_s.should contain("Shell: nu")
    stderr.to_s.should eq("")
  end

  it "reads the shell from config when no override is provided" do
    BaiSpecSupport.with_env("BAI_SHELL", nil) do
      BaiSpecSupport.with_config({"shell" => "fish"}) do
        Bai::SystemContext.shell_name.should eq("fish")
      end
    end
  end

  it "lets env vars override the shell config file" do
    BaiSpecSupport.with_env("BAI_SHELL", "bash") do
      BaiSpecSupport.with_config({"shell" => "fish"}) do
        Bai::SystemContext.shell_name.should eq("bash")
      end
    end
  end

  it "returns 1 for an invalid shell override" do
    stdout = IO::Memory.new
    stderr = IO::Memory.new

    Bai.run(["--show-config", "--shell", "bogus"], stdout: stdout, stderr: stderr).should eq(1)

    stdout.to_s.should eq("")
    stderr.to_s.should eq("bai: unsupported shell: bogus\n")
  end

  it "lets env vars override config files" do
    BaiSpecSupport.with_env("BAI_PROVIDER", "anthropic") do
      BaiSpecSupport.with_config({"provider" => "openai"}) do
        Bai::Provider.current.should eq("anthropic")
      end
    end
  end

  it "reads API keys from config files" do
    BaiSpecSupport.with_env("ANTHROPIC_API_KEY", nil) do
      BaiSpecSupport.with_config({"anthropic_api_key" => "file-key"}) do
        Bai::Config.value("ANTHROPIC_API_KEY").should eq("file-key")
      end
    end
  end

  it "uses a prompt_file config value to load the addendum" do
    prompt_path : String? = "/tmp/bai-custom-prompt-#{Process.pid}.md"

    BaiSpecSupport.with_config({"prompt_file" => prompt_path.not_nil!}) do
      File.write(prompt_path.not_nil!, "Prefer fd over find.")

      Bai::Prompt.system.should contain("Prefer fd over find.")
    end
  ensure
    if path = prompt_path
      File.delete(path) if File.exists?(path)
    end
  end

  it "uses the config-dir prompt.md by default" do
    BaiSpecSupport.with_config({"prompt.md" => "Prefer eza over ls."}) do
      Bai::Prompt.system.should contain("Prefer eza over ls.")
    end
  end

  it "returns 1 for an unsupported provider" do
    BaiSpecSupport.with_env("BAI_PROVIDER", "bogus") do
      stdout = IO::Memory.new
      stderr = IO::Memory.new

      Bai.run(["list", "files"], stdout: stdout, stderr: stderr).should eq(1)

      stdout.to_s.should eq("")
      stderr.to_s.should eq("bai: unsupported provider: bogus\n")
    end
  end

  it "uses argv text as the query when provided" do
    BaiSpecSupport.with_env("ANTHROPIC_API_KEY", nil) do
      BaiSpecSupport.with_config({"anthropic_api_key" => "test-key"}) do
        stdout = IO::Memory.new
        stderr = IO::Memory.new
        seen_query = ""

        requester = ->(query : String, options : Bai::RequestOptions) do
          seen_query = query
          Bai::GenerationResult.new("ls -lt")
        end

        Bai.run(["list", "files"], stdout: stdout, stderr: stderr, command_requester: requester).should eq(0)

        seen_query.should eq("list files")
        stdout.to_s.should eq("ls -lt")
        stderr.to_s.should eq("")
      end
    end
  end

  it "falls back to stdin when argv is empty and stdin is piped" do
    BaiSpecSupport.with_env("ANTHROPIC_API_KEY", nil) do
      BaiSpecSupport.with_config({"anthropic_api_key" => "test-key"}) do
        stdin = IO::Memory.new("list files from stdin\n")
        stdout = IO::Memory.new
        stderr = IO::Memory.new
        seen_query = ""

        requester = ->(query : String, options : Bai::RequestOptions) do
          seen_query = query
          Bai::GenerationResult.new("find . -type f")
        end

        Bai.run(
          [] of String,
          stdin: stdin,
          stdout: stdout,
          stderr: stderr,
          stdin_tty: false,
          command_requester: requester
        ).should eq(0)

        seen_query.should eq("list files from stdin")
        stdout.to_s.should eq("find . -type f")
        stderr.to_s.should eq("")
      end
    end
  end

  it "does not call the clipboard copier when --no-copy is set" do
    BaiSpecSupport.with_env("ANTHROPIC_API_KEY", nil) do
      BaiSpecSupport.with_config({"anthropic_api_key" => "test-key"}) do
        stdout = IO::Memory.new
        stderr = IO::Memory.new
        clipboard_called = false

        requester = ->(query : String, options : Bai::RequestOptions) { Bai::GenerationResult.new("echo test") }
        copier = ->(text : String) do
          clipboard_called = true
          true
        end

        Bai.run(
          ["--no-copy", "echo", "something"],
          stdout: stdout,
          stderr: stderr,
          command_requester: requester,
          clipboard_copier: copier
        ).should eq(0)

        clipboard_called.should be_false
        stdout.to_s.should eq("echo test")
        stderr.to_s.should eq("")
      end
    end
  end

  it "prints the explanation to stderr when --explain is set" do
    stdout = IO::Memory.new
    stderr = IO::Memory.new

    requester = ->(query : String, options : Bai::RequestOptions) do
      options.explain.should be_true
      Bai::GenerationResult.new("rg foo src", "Uses ripgrep to search the source tree quickly.")
    end

    Bai.run(["--explain", "find", "foo"], stdout: stdout, stderr: stderr, command_requester: requester).should eq(0)

    stdout.to_s.should eq("rg foo src")
    stderr.to_s.should eq("why: Uses ripgrep to search the source tree quickly.\n")
  end

  it "prints machine-readable json to stdout when --json is set" do
    stdout = IO::Memory.new
    stderr = IO::Memory.new

    requester = ->(query : String, options : Bai::RequestOptions) do
      options.json.should be_true
      Bai::GenerationResult.new("rg foo src", "Uses ripgrep to search the source tree quickly.")
    end

    Bai.run(["--json", "find", "foo"], stdout: stdout, stderr: stderr, command_requester: requester).should eq(0)

    json = JSON.parse(stdout.to_s).as_h
    json["command"].as_s.should eq("rg foo src")
    json["explanation"].as_s.should eq("Uses ripgrep to search the source tree quickly.")
    json["provider"].as_s.should eq("anthropic")
    json["strict"].as_bool.should be_false
    stderr.to_s.should eq("")
  end

  it "keeps explanation in json instead of stderr when --json and --explain are combined" do
    stdout = IO::Memory.new
    stderr = IO::Memory.new

    requester = ->(query : String, options : Bai::RequestOptions) do
      options.json.should be_true
      options.explain.should be_true
      Bai::GenerationResult.new("ls -lt", "Lists files sorted by modification time.")
    end

    Bai.run(["--json", "--explain", "list", "files"], stdout: stdout, stderr: stderr, command_requester: requester).should eq(0)

    json = JSON.parse(stdout.to_s).as_h
    json["command"].as_s.should eq("ls -lt")
    json["explanation"].as_s.should eq("Lists files sorted by modification time.")
    stderr.to_s.should eq("")
  end

  it "returns 1 in strict mode when no command is produced" do
    stdout = IO::Memory.new
    stderr = IO::Memory.new

    requester = ->(query : String, options : Bai::RequestOptions) do
      options.strict.should be_true
      Bai::GenerationResult.new("", "The request is ambiguous about which directory to search.")
    end

    Bai.run(["--strict", "find", "recent", "files"], stdout: stdout, stderr: stderr, command_requester: requester).should eq(1)

    stdout.to_s.should eq("")
    stderr.to_s.should eq("bai: The request is ambiguous about which directory to search.\n")
  end

  it "returns json plus a nonzero exit code in strict json mode when no command is produced" do
    stdout = IO::Memory.new
    stderr = IO::Memory.new

    requester = ->(query : String, options : Bai::RequestOptions) do
      options.json.should be_true
      options.strict.should be_true
      Bai::GenerationResult.new("", "The request is ambiguous about which directory to search.")
    end

    Bai.run(["--json", "--strict", "find", "recent", "files"], stdout: stdout, stderr: stderr, command_requester: requester).should eq(1)

    json = JSON.parse(stdout.to_s).as_h
    json["command"].as_s.should eq("")
    json["explanation"].as_s.should eq("The request is ambiguous about which directory to search.")
    json["strict"].as_bool.should be_true
    stderr.to_s.should eq("")
  end
end

describe Bai::AnthropicClient do
  it "extracts the first usable text block" do
    response = {
      content: [
        {type: "tool_use", id: "toolu_123", name: "noop"},
        {type: "text", text: "ls -lt"},
      ],
    }.to_json

    Bai::AnthropicClient.extract_command(response).should eq("ls -lt")
  end

  it "sanitizes fenced command output" do
    response = {
      content: [
        {type: "text", text: "```bash\nfind . -type f\n```"},
      ],
    }.to_json

    Bai::AnthropicClient.extract_command(response).should eq("find . -type f")
  end

  it "raises a clear error when content is missing" do
    expect_raises(Exception, "API response missing content array") do
      Bai::AnthropicClient.extract_command({id: "msg_123"}.to_json)
    end
  end

  it "raises a clear error when no text blocks are usable" do
    response = {
      content: [
        {type: "tool_use", id: "toolu_123", name: "noop"},
        {type: "text", text: "   "},
      ],
    }.to_json

    expect_raises(Exception, "API response contained no usable text content") do
      Bai::AnthropicClient.extract_command(response)
    end
  end

  it "raises a clear error when the response is invalid json" do
    expect_raises(Exception, "API response was not valid JSON") do
      Bai::AnthropicClient.extract_command("{not json")
    end
  end
end

describe Bai::OpenAIClient do
  it "uses output_text when present" do
    response = {
      output_text: "ls -lt",
      output: [] of String,
    }.to_json

    Bai::OpenAIClient.extract_command(response).should eq("ls -lt")
  end

  it "extracts the first usable output_text content block" do
    response = {
      output: [
        {type: "reasoning", summary: [] of String},
        {
          type:    "message",
          role:    "assistant",
          content: [
            {type: "refusal", refusal: "no"},
            {type: "output_text", text: "find . -type f"},
          ],
        },
      ],
    }.to_json

    Bai::OpenAIClient.extract_command(response).should eq("find . -type f")
  end

  it "sanitizes fenced output_text content" do
    response = {
      output: [
        {
          type:    "message",
          role:    "assistant",
          content: [
            {type: "output_text", text: "```sh\nrg foo src\n```"},
          ],
        },
      ],
    }.to_json

    Bai::OpenAIClient.extract_command(response).should eq("rg foo src")
  end

  it "raises a clear error when output is missing" do
    expect_raises(Exception, "API response missing output array") do
      Bai::OpenAIClient.extract_command({id: "resp_123"}.to_json)
    end
  end

  it "raises a clear error when no usable output text is present" do
    response = {
      output: [
        {
          type:    "message",
          role:    "assistant",
          content: [
            {type: "output_text", text: "   "},
          ],
        },
      ],
    }.to_json

    expect_raises(Exception, "API response contained no usable output text") do
      Bai::OpenAIClient.extract_command(response)
    end
  end

  it "raises a clear error when the response is invalid json" do
    expect_raises(Exception, "API response was not valid JSON") do
      Bai::OpenAIClient.extract_command("{not json")
    end
  end
end

describe Bai::ModelOutput do
  it "parses a structured explain response" do
    options = Bai::RequestOptions.new(explain: true)
    text = %({"command":"ls -lt","explanation":"Lists files sorted by modification time."})

    result = Bai::ModelOutput.parse(text, options)

    result.command.should eq("ls -lt")
    result.explanation.should eq("Lists files sorted by modification time.")
  end

  it "sanitizes fenced structured output" do
    options = Bai::RequestOptions.new(explain: true)
    text = <<-TEXT
      ```json
      {"command":"find . -type f","explanation":"Searches for regular files recursively."}
      ```
      TEXT

    result = Bai::ModelOutput.parse(text, options)

    result.command.should eq("find . -type f")
    result.explanation.should eq("Searches for regular files recursively.")
  end

  it "raises a clear error for invalid structured json" do
    options = Bai::RequestOptions.new(explain: true)

    expect_raises(Exception, "model response was not valid JSON") do
      Bai::ModelOutput.parse("not json", options)
    end
  end
end
