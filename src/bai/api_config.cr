# :nodoc:
module Bai
  # :nodoc:
  struct ApiConfig
    ANTHROPIC_DEFAULT_BASE_URL = "https://api.anthropic.com"
    ANTHROPIC_DEFAULT_MODEL    = "claude-haiku-4-5-20251001"
    OPENAI_DEFAULT_BASE_URL    = "https://api.openai.com"
    OPENAI_DEFAULT_MODEL       = "gpt-5-mini"
    LOCAL_DEFAULT_BASE_URL     = "http://localhost:11434"

    DEPRECATED_SETTINGS = {
      "BAI_ANTHROPIC_MODEL" => "BAI_MODEL",
      "BAI_OPENAI_MODEL"    => "BAI_MODEL",
      "BAI_LOCAL_MODEL"     => "BAI_MODEL",
      "BAI_OPENAI_BASE_URL" => "BAI_BASE_URL",
      "BAI_LOCAL_BASE_URL"  => "BAI_BASE_URL",
    }

    getter provider : String
    getter api_type : String
    getter base_url : String
    getter api_key : String?
    getter model : String

    def initialize(@provider : String, @api_type : String, @base_url : String, @api_key : String?, @model : String)
    end

    def self.resolve : self
      ensure_no_deprecated_settings!

      provider = normalized_value("BAI_PROVIDER") || "anthropic"
      validate_provider!(provider)

      api_type = normalized_value("BAI_API_TYPE") || default_api_type(provider)
      validate_api_type!(api_type)

      base_url = normalize_base_url(Config.value("BAI_BASE_URL") || default_base_url(provider))
      api_key = resolved_api_key(provider)
      model = Config.value("BAI_MODEL") || default_model(provider)

      if provider == "local" && model.strip.empty?
        raise "BAI_MODEL not set for local provider"
      end

      new(provider, api_type, base_url, api_key, model)
    end

    def self.current_provider : String
      normalized_value("BAI_PROVIDER") || "anthropic"
    end

    def endpoint(path : String) : String
      if base_url.ends_with?("/v1") && path.starts_with?("/v1/")
        "#{base_url}#{path[3..]}"
      else
        "#{base_url}#{path}"
      end
    end

    def api_key! : String
      value = @api_key
      return value if value

      case provider
      when "anthropic"
        raise "BAI_API_KEY or ANTHROPIC_API_KEY not set"
      when "openai"
        raise "BAI_API_KEY or OPENAI_API_KEY not set"
      else
        raise "BAI_API_KEY not set"
      end
    end

    private def self.resolved_api_key(provider : String) : String?
      api_key = Config.value("BAI_API_KEY")
      return api_key if api_key

      case provider
      when "anthropic"
        Config.value("ANTHROPIC_API_KEY")
      when "openai"
        Config.value("OPENAI_API_KEY")
      when "local"
        "none"
      end
    end

    private def self.default_api_type(provider : String) : String
      case provider
      when "anthropic"
        "anthropic"
      when "openai"
        "openai_responses"
      when "local"
        "openai_chat"
      else
        raise "unsupported provider: #{provider}"
      end
    end

    private def self.default_base_url(provider : String) : String
      case provider
      when "anthropic"
        ANTHROPIC_DEFAULT_BASE_URL
      when "openai"
        OPENAI_DEFAULT_BASE_URL
      when "local"
        LOCAL_DEFAULT_BASE_URL
      else
        raise "unsupported provider: #{provider}"
      end
    end

    private def self.default_model(provider : String) : String
      case provider
      when "anthropic"
        ANTHROPIC_DEFAULT_MODEL
      when "openai"
        OPENAI_DEFAULT_MODEL
      when "local"
        ""
      else
        raise "unsupported provider: #{provider}"
      end
    end

    private def self.ensure_no_deprecated_settings!
      DEPRECATED_SETTINGS.each do |old_name, new_name|
        if ENV[old_name]?.try { |value| !value.strip.empty? }
          raise "#{old_name} is no longer supported. Use #{new_name} instead."
        end

        old_path = Config.file_path(old_name)
        next unless old_path && File.exists?(old_path)
        next if File.read(old_path).strip.empty?

        new_path = Config.file_path(new_name) || new_name.downcase.sub(/\Abai_/, "")
        raise "#{old_path} is no longer supported. Use #{new_path} instead."
      end
    end

    private def self.normalized_value(name : String) : String?
      value = Config.value(name).try(&.strip.downcase)
      value unless value.nil? || value.empty?
    end

    private def self.normalize_base_url(value : String) : String
      value.strip.gsub(/\/+\z/, "")
    end

    private def self.validate_provider!(provider : String)
      return if {"anthropic", "openai", "local"}.includes?(provider)

      raise "unsupported provider: #{provider}"
    end

    private def self.validate_api_type!(api_type : String)
      return if {"anthropic", "openai_responses", "openai_chat"}.includes?(api_type)

      raise "unsupported API type: #{api_type}"
    end
  end
end
