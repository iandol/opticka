require 'eventmachine'

module UDPServer
  def post_init
    puts "we've connected!"
  end
  
  def receive_data(data)
    p data
  end
end

EventMachine::run do
  EventMachine::open_datagram_socket('127.0.0.1', 7777, UDPServer)
  EventMachine::add_periodic_timer(5) { puts "." }
end