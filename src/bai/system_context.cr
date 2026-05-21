# :nodoc:
module Bai::SystemContext
  def self.gather : String
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
end
