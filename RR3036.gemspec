# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'RR3036/version'

Gem::Specification.new do |spec|
  spec.name          = "RR3036"
  spec.version       = RR3036::VERSION
  spec.authors       = ["Sascha Willuweit"]
  spec.email         = ["s@rprojekt.org"]
  spec.description   = %q{RR3036 RFID (ISO/IEC 15693, ISO/IEC 14443A+B) connector written in Ruby.}
  spec.summary       = %q{RR3036 RFID (ISO/IEC 15693, ISO/IEC 14443A+B) reader/writer written in Ruby. Available at http://www.rfid-in-china.com/2008-09-02/products_detail_2133.html (e.g. HF RFID Reader - 02) and http://www.rfidshop.com.hk/ (e.g. HF-TP-RW-USB-D1).}
  spec.homepage      = "https://github.com/545ch4/RR3036"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "serialport"

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
end
