# :nodoc:
module Bai::Config
  def self.dir : String?
    return ENV["BAI_CONFIG_DIR"]? if ENV["BAI_CONFIG_DIR"]?

    home = ENV["HOME"]?
    return nil unless home

    base = ENV["XDG_CONFIG_HOME"]? || "#{home}/.config"
    "#{base}/bai"
  end

  def self.value(name : String, legacy : String? = nil) : String?
    names = [name]
    names << legacy if legacy

    names.each do |env_name|
      value = ENV[env_name]?
      return value unless blank?(value)
    end

    names.each do |env_name|
      value = read_file_value(env_name)
      return value unless blank?(value)
    end

    nil
  end

  def self.file_path(name : String) : String?
    config_dir = dir
    return nil unless config_dir
    "#{config_dir}/#{file_name(name)}"
  end

  private def self.file_name(name : String) : String
    name.downcase.sub(/\Abai_/, "")
  end

  private def self.read_file_value(name : String) : String?
    path = file_path(name)
    return nil unless path && File.exists?(path)

    value = File.read(path).strip
    blank?(value) ? nil : value
  rescue
    nil
  end

  private def self.blank?(value : String?) : Bool
    value.nil? || value.strip.empty?
  end
end
