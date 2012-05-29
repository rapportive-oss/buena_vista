Gem::Specification.new do |s|
  s.name = "buena_vista"
  s.version = "1.0.0"
  s.platform = Gem::Platform::RUBY
  s.author = "Martin Kleppmann"
  s.email = "martin@rapportive.com"
  s.homepage = "http://github.com/rapportive-oss/buena_vista"
  s.summary = "Highly intelligent truncation for space-constrained text display."
  s.description = "Provides context-sensitive truncation of strings, trying at all costs to avoid breaking in the middle of a word."
  s.files = `git ls-files`.lines.map(&:strip)
  s.require_path = "lib"
end
