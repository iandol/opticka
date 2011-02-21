require 'rubygems'
require 'eventmachine'

$PORT    = 3333
$VERSION = 1.01
$COMMAND = /^@(?<cmd>[^\|]+)\|(?<data>.*)/

module UDPServer

	#Start method
	def post_init
		puts "UDP Server V#{$VERSION} (Ruby: #{RUBY_VERSION}) Connected!"
	end

	#We've received data - parse it
	def receive_data data
		puts "\n>>>They sent: #{data} at #{Time.new}"
		matches = $COMMAND.match(data)

		if matches['cmd'] =~ /echo/i
			puts("ECHO ACTIVE")
			send_data "#{matches[:data]}"
		elsif matches['cmd'] =~ /quit/i
			puts("QUIT ACTIVE")
			close_connection
		elsif matches['cmd'] =~ /exit/i
			puts("EXIT ACTIVE")
			EventMachine::stop_event_loop
		end

	end

	def unbind
		puts "Someone disconnected from the server!"
	end
end

EventMachine::run do
	EventMachine::open_datagram_socket('0', $PORT, UDPServer)
	EventMachine::add_periodic_timer(10) { printf ".\t" }
	EventMachine::add_periodic_timer(100.1) { printf "#{Time.new}\n" }
end