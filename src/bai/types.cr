# :nodoc:
module Bai
  record RequestOptions,
    explain : Bool = false,
    json : Bool = false,
    strict : Bool = false,
    shell_override : String? = nil

  record GenerationResult,
    command : String,
    explanation : String? = nil
end
