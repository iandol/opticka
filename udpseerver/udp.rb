require 'rubygems'
require 'eventmachine'

module UDPServer
  def post_init
    puts "We've connected!"
  end
  
  def receive_data data
    puts ">>> they sent: #{data}"
    send_data ">>> you sent: #{data}"
    close_connection if data =~ /quit/i
  end
end

EventMachine::run do
  EventMachine::open_datagram_socket('127.0.0.1', 7777, UDPServer)
  EventMachine::add_periodic_timer(5) { puts "." }
end