# :nodoc:
module Bai::Clipboard
  def self.enabled?(override : Bool?) : Bool
    return override unless override.nil?
    case ENV["BAI_CLIPBOARD"]?.try(&.downcase)
    when "0", "off", "false", "no" then false
    else                                true
    end
  end

  def self.copy(text : String) : Bool
    tool = detect_tool
    return false unless tool
    cmd, args = tool
    status = Process.run(cmd, args, input: IO::Memory.new(text))
    status.success?
  rescue
    false
  end

  private def self.detect_tool : Tuple(String, Array(String))?
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
end
