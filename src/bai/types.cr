# :nodoc:
module Bai
  # Options that change how a command-generation request is prompted and rendered.
  record RequestOptions,
    explain : Bool = false,
    json : Bool = false,
    strict : Bool = false,
    shell_override : String? = nil

  # The parsed model response returned by provider clients.
  record GenerationResult,
    command : String,
    explanation : String? = nil
end
