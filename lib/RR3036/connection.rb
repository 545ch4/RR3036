# coding: utf-8
require "serialport"

# RR3036 RFID (ISO15963, 14443A+B) reader/writer.
#
# Author::    Sascha Willuweit  (s@rprojekt.org)
# Copyright:: Copyright (c) 2013 Sascha Willuweit
# License::   MIT
module RR3036
	CMDS = {
		:init_device => {:cmd => 0x00, :state => 0x00},
		:close_rf => {:cmd => 0x00, :state => 0x01},
		:open_rf => {:cmd => 0x00, :state => 0x02},
		:led => {:cmd => 0x00, :state => 0x07},
		:change_to_iso15693 => {:cmd => 0x00, :state => 0x06},
		:change_to_iso14443a => {:cmd => 0x00, :state => 0x05},
		:change_to_iso14443b => {:cmd => 0x00, :state => 0x09},
		:iso15693_inventory => {:cmd => 0x01, :state => 0x06},
		:iso15693_read_4byte => {:cmd => 0x20, :state => 0x00},
		:iso15693_write_4byte => {:cmd => 0x21, :state => 0x00},
		:iso15693_tag_info => {:cmd =>0x2B, :state => 0x00}
	}
	OPERATION_MODES = [:iso15693, :iso14443a, :iso14443b]
	CRC_POLYNOMIAL = 0x8408
	ERROR_MSG = {
		0x01 => {:msg => 'Command operand length error', :description => 'Return status 1 to host when the number of command operands doesn’t conform to the command request.'},
		0x02 => {:msg => 'Command not supported', :description => 'Return status 2 to host when the reader does not support the command the host sends.'},
		0x03 => {:msg => 'Operand out of range', :description => 'Return status 3 to host when one or more operand of command data block sent by host are out of range.'},
		0x04 => {:msg => 'Operation Not Availible', :description => 'Return status 4 to host when the requested operation is not available for the reader.'},
		0x05 => {:msg => 'Inductive field closed', :description => 'Return status 5 to host when the inductive field is closed and the host sends a ISO15693 ISO14443 protocol command.'},
		0x06 => {:msg => 'EEPROM operation error', :description => 'Return status 6 to host when the reader encounters error in EEPROM access.'},
		0x0A => {:msg => 'ISO15693 Inventory Operation Error', :description => 'Return status 0x0A when the reader executing an ISO15693 Inventory command does not get one complete tag’s UID before InventoryScanTime overflows.'},
		0x0B => {:msg => 'ISO15693 Inventory Operation Error', :description => 'Return status 0x0B when the reader executing an ISO15693 Inventory command does not get all tags’ UIDs before InventoryScanTime overflows.'},
		0x0C => {:msg => 'ISO15693 Tag Response Error', :description => 'Return status 0x0C when the reader finds one or more tag response in a way that is not compatible with ISO15693 protocol definition.'},
		0x0E => {:msg => 'ISO15693 Operation No Tag Error', :description => 'Return ox0E when the reader finds no active tag in the inductive field.'},
		0x1F => {:msg => 'Protocol model error', :description => 'Return status 0x1F when the reader accepts a command not conforming to its current protocol model. For example, the reader accepts a ISO14443A protocol command but its current model is ISO15693.'},
		0x0F => {:further_descriptions => {
			0x01 => 'Commands not support. For example: invalid command code',
			0x02 => 'Commands can not be identified. For example: invalid command format',
			0x03 => 'Operation not supported',
			0x0f => 'Unknown error',
			0x10 => 'Appointed block is not available or don’t exist.',
			0x11 => 'Appointed block has been locked and can’t be locked again.',
			0x12 => 'Appointed block is locked and can’t change its content.',
			0x13 => 'Appointed block does not operate normally.',
			0x14 => 'Appointed block can’t be locked normally.'
		}, :msg => 'ISO5693 Operation Extension error', :description => 'Return status 0x0F when an error occurred in ISO15693 command execution and the further information of the error is defined by the Error_code in response data block.'},
		0x10 => {:further_descriptions => {
			0x10 => 'Halt failed',
			0x20 => 'No ISO14443A card in the inductive area.',
			0x21 => 'select failed',
			0x22 => 'authentication failed',
			0x23 => 'read failed',
			0x24 => 'write failed',
			0x25 => 'e-wallet initialization failed',
			0x26 => 'read value failed',
			0x27 => 'decrement/Increment failed',
			0x28 => 'transfer failed',
			0x29 => 'write/read E2PROM failes',
			0x2A => 'load key failed',
			0x2B => 'checkwrite failed',
			0x2C => 'data for checkwrite error',
			0x2D => 'value operation failed',
			0x2E => 'Ultralight card write failed',
			0x30 => 'Anti-collision failed',
			0x31 => 'Multiple card entering inductive area forbidden',
			0x32 => 'Mifare I and Ultralight collision error',
			0x33 => 'Ultralight card collision failed.'
		}, :msg => 'ISO14443A Operation error', :description => 'Return status 0x10 when an error occurred in ISO14443A command execution and the further information of the error is defined by the Error_code in response data block.'},
		0x1B => {:further_descriptions => {
			0x34 => 'No ISO14443B card in the inductive area.',
			0x35 => 'select failed',
			0x36 => 'halt failed',
			0x37 => 'execute transparent command failed',
			0x38 => 'Anticollision failed'
		}, :msg => 'ISO14443B Operation error', :description => 'Return status 0x1B when an error occurred in ISO14443B command execution and the further information of the error is defined by the Error_code in response data block.'}
	}

	class Connection
		attr_reader :port, :com_addr, :operation

		def initialize(device, _options = {})
			options = {:baud => 19200, :data_bits => 8, :stop_bit => 1, :parity => SerialPort::NONE, :mode => OPERATION_MODES.first}.update (_options||{})
			@operation = options[:mode]
			@com_addr = 0x00
			set_and_open_port(device, _options)
		end

		def set_and_open_port(device, _options = {})
			options = {:baud => 19200, :data_bits => 8, :stop_bit => 1, :parity => SerialPort::NONE, :read_timeout => 1000}.update (_options||{})
			@port = SerialPort.new(device, options[:baud], options[:data_bits], options[:stop_bit], options[:parity])
			port.read_timeout = options[:read_timeout]
		end

		def send_cmd(cmd, _options = {})
			options = {:data => '', :continue_on_errors => [], :dont_report_crc_failures => false}.update (_options||{})

			return false unless CMDS.include? cmd

			# len | com_addr | cmd | state | data | lsb-crc16 | msb-crc16
			cmd_data_block = [options[:data].bytes.size + 5, com_addr, CMDS[cmd][:cmd], (operation == :iso15693 ? CMDS[cmd][:state] & 0x0F : CMDS[cmd][:state] | 0xF0)] + options[:data].bytes
			cmd_data_block += crc(cmd_data_block)
			written_bytes = port.write cmd_data_block.pack('C*')
			port.flush

			response = {:len => 0x00, :com_addr => 0x00, :status => 0x00, :data => [], :crc => [0x00, 0x00]}
			response[:len] = port.readbyte
			(response[:addr], response[:status]) = port.read(2).bytes.to_a
			response[:data] = port.read(response[:len] - 4).bytes.pack('C*')
			response[:crc] = port.read(2).bytes.pack('C*')
			response[:crc_calc] = crc([response[:len], response[:addr], response[:status]] + response[:data].bytes).pack('C*')
			if response[:status] > 0 && !continue_on_errors.include?(response[:status])
				puts "Error: " << (ERROR_MSG[response[:status]][:msg].nil? ? 'UNKNOWN ERROR' : (ERROR_MSG[response[:status]][:msg] + ' ' + ERROR_MSG[response[:status]][:description]) + ' ' + response[:data].inspect) << (ERROR_MSG[response[:status]] && ERROR_MSG[response[:status]][:further_descriptions] && !response[:data].empty? && ERROR_MSG[response[:status]][:further_descriptions][response[:data]] ? ERROR_MSG[response[:status]][:further_descriptions][response[:data]] : '')
			end
			if response[:crc] != response[:crc_calc] && !options[:dont_report_crc_failures]
				puts "Error: CRC doesn't match."
			end
			return response
		end

		def method_missing(m, *args)
			if CMDS[m.to_sym]
				send_cmd(m.to_sym, *args)
			else
				super
			end
 		end

		def dump_iso15693
			response = init_device
			puts "Init version=%i, RFU=%i, reader_type=%s, tr_type=%i, inventory_scan_time=%i"%(response[:data].unpack('S>S>hS>C'))

			response = change_to_iso15693
			puts "Changed to ISO15693" if response[:status] == 0

			while(true)
				tags = []
				tag = nil
				puts "Please press any key to start inventory"
				gets
				response = iso15693_inventory(:continue_on_errors => [0x0E])
				((response[:len] - 4) / 9).times do |i|
					(dsfid, uid) = response[:data][((i - 1) * 9)..((i * 9) - 1)].unpack('Ca8')
					puts "#{i}) ISO15693 tag #{bytes_to_hex_string uid} with uid=#{uid.unpack('i')} (dsfid=#{dsfid})"
					tags << {:block_data => [], :block_security_flag => [], :dsfid => dsfid, :uid => uid}
				end
				if tags.empty?
					continue
				else
					puts "Please select a tag:"
					tag = tags[gets.strip.to_i]
					continue if tag.nil?
				end

				info = iso15693_tag_info(:data => tag[:uid])
				(tag[:flag], _uid, _dsfid, tag[:afi], tag[:mem_size], tag[:ic_ref]) = info[:data].unpack('hh8CCS>C')
				puts "ISO15693 tag #{bytes_to_hex_string tag[:uid]} info: flag=#{tag[:flag]}, afi=#{tag[:afi]}, mem_size=#{tag[:mem_size]}, ic_ref=#{tag[:ic_ref]}"
				# TODO 4-byte vs. 8-byte reads
				64.times do |i|
					block = iso15693_read_4byte(:data => tag[:uid] + i.chr)
					tag[:block_data] << block[:data][1..-1]
					tag[:block_security_flag] << block[:data][0]
					puts "ISO15693 tag #{bytes_to_hex_string tag[:uid]} block #{i}: #{bytes_to_hex_string block[:data][0]} #{block[:data][1..-1].inspect} (#{bytes_to_hex_string block[:data][1..-1]})"
				end

				puts "ISO15693 tag #{bytes_to_hex_string tag[:uid]} joined together: #{tag[:block_data].join.strip.inspect}"
			end
		end

	private
	
		def bytes_to_hex_string(b)
			(b.respond_to?(:bytes) ? b.bytes : b).map{|x| ('%2x'%(x)).sub(' ', '0')}.join
		end

		def crc(data)
			crc_value = 0xFFFF
			(data.kind_of?(Array) ? data : data.bytes).each do |b|
				crc_value = crc_value ^ b
				8.times do
					if (crc_value & 0x0001) == 0x0001
						crc_value = (crc_value >> 1) ^ CRC_POLYNOMIAL
					else
						crc_value = (crc_value >> 1)
					end
				end
			end
			# LSB-CRC-16, MSB-CRC16
			return [crc_value & 0x00FF, (crc_value >> 8) & 0x00FF]
		end
	end
end