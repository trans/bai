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
end

describe Bai do
  it "exposes a version string" do
    Bai::VERSION.should eq("0.2.0")
  end

  it "prints help to stdout" do
    stdout = IO::Memory.new
    stderr = IO::Memory.new

    Bai.run(["--help"], stdout: stdout, stderr: stderr).should eq(0)

    stdout.to_s.should contain("Usage: bai [options]")
    stderr.to_s.should eq("")
  end

  it "prints the version without exiting the process" do
    stdout = IO::Memory.new
    stderr = IO::Memory.new

    Bai.run(["--version"], stdout: stdout, stderr: stderr).should eq(0)

    stdout.to_s.should eq("#{Bai::VERSION}\n")
    stderr.to_s.should eq("")
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

  it "uses argv text as the query when provided" do
    BaiSpecSupport.with_env("ANTHROPIC_API_KEY", "test-key") do
      stdout = IO::Memory.new
      stderr = IO::Memory.new
      seen_api_key = ""
      seen_query = ""

      requester = ->(api_key : String, query : String) do
        seen_api_key = api_key
        seen_query = query
        "ls -lt"
      end

      Bai.run(["list", "files"], stdout: stdout, stderr: stderr, command_requester: requester).should eq(0)

      seen_api_key.should eq("test-key")
      seen_query.should eq("list files")
      stdout.to_s.should eq("ls -lt")
      stderr.to_s.should eq("")
    end
  end

  it "falls back to stdin when argv is empty and stdin is piped" do
    BaiSpecSupport.with_env("ANTHROPIC_API_KEY", "test-key") do
      stdin = IO::Memory.new("list files from stdin\n")
      stdout = IO::Memory.new
      stderr = IO::Memory.new
      seen_query = ""

      requester = ->(api_key : String, query : String) do
        seen_query = query
        "find . -type f"
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

  it "does not call the clipboard copier when --no-copy is set" do
    BaiSpecSupport.with_env("ANTHROPIC_API_KEY", "test-key") do
      stdout = IO::Memory.new
      stderr = IO::Memory.new
      clipboard_called = false

      requester = ->(api_key : String, query : String) { "echo test" }
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
