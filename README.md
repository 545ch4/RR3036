# RR3036

RR3036 RFID (ISO15963, 14443A+B) reader/writer written in Ruby. Available at http://www.rfid-in-china.com/2008-09-02/products_detail_2133.html (e.g. HF RFID Reader - 02) and http://www.rfidshop.com.hk/ (e.g. HF-TP-RW-USB-D1)


## Installation

Add this line to your application's Gemfile:

    gem 'RR3036'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install RR3036


## Usage

	$ con = RR3036::Connection.new(<path_to_your_serial_line_device>, :mode => :iso15693)
	$ con.dump_iso15693


## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
