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
    EventMachine::stop_event_loop if data =~ /exit/i
  end

  def unbind
       puts "-- someone disconnected from the server!"
  end
end

EventMachine::run do
  EventMachine::open_datagram_socket('127.0.0.1', 4321, UDPServer)
  EventMachine::add_periodic_timer(10) { puts "." }
end