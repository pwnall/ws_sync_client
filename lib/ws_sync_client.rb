require 'socket'  # For Addrinfo.

require 'websocket'

# Synchronous socket.
class WsSyncClient
  # Create a socket.
  #
  # @param [String] url a ws:// URL
  # @param [Hash] options socket creation options
  # @option options [Socket] raw create this socket on top of a raw socket.
  def initialize(url, options = {})
    @url = url
    @handshake = WebSocket::Handshake::Client.new url: @url

    if options[:raw]
      @socket = options[:raw]
    else
      @socket = self.class.raw_socket @handshake.host, @handshake.port
    end
    @max_recv = 4096

    handshake
    @closed = false
    @incoming = WebSocket::Frame::Incoming::Client.new(
        version: @handshake.version)
    if leftovers = @handshake.leftovers
      @incoming << leftovers
    end
  end

  # Send a WebSocket frame.
  #
  # @param [String] data the data to be sent or :closed if the socket is closed
  def send_frame(data)
    return :closed if @closed

    frame = WebSocket::Frame::Outgoing::Client.new version: @handshake.version,
        data: data, type: :text
    @socket.send frame.to_s, 0
  end

  # Receive a WebSocket frame.
  #
  # @return [String] the frame data or :closed if the socket is closed
  def recv_frame
    loop do
      return :closed if @closed

      frame = @incoming.next
      if frame.nil?
        recv_bytes
        next
      end

      case frame.type
      when :text
        return frame.data
      when :binary
        return frame.data
      when :ping
        send_pong frame.data
      when :pong
        # Ignore pong, since we don't ping.
      when :close
        @socket.close
        @closed = true
      end
    end
  end

  # Closes the WebSocket.
  #
  # @param [Integer] code
  # @param [String] reason
  def close(code = 0, reason = '')
    return true if @closed

    frame = WebSocket::Frame::Outgoing::Client.new version: @handshake.version,
        data: '', type: :close
    @socket.send frame.to_s, 0
    @socket.close
    @closed = true
  end

  # Complete the WebSocket handshake.
  #
  # @private
  # This is used in the constructor
  def handshake
    return :closed if @closed

    @socket.send @handshake.to_s, 0

    until @handshake.finished?
      bytes = @socket.recv @max_recv
      @handshake << bytes
    end
    unless @handshake.valid?
      raise RuntimeError, 'Invalid WebSocket handshake'
    end
  end
  private :handshake

  # Receive a packet from the underlying raw socket.
  #
  # @private
  # This is used in {WsSync#recv_frame}.
  def recv_bytes
    return :closed if @closed

    bytes = @socket.recv @max_recv

    if bytes.empty?
      @socket.close
      @closed = true
      return :closed
    end

    @incoming << bytes
  end
  private :recv_bytes

  # Send
  def send_pong(ping_data)
    return :closed if @closed

    frame = WebSocket::Frame::Outgoing::Client.new version: @handshake.version,
        data: ping_data, type: :pong
    @socket.send frame.to_s, 0
  end
  private :send_pong

  # Create a raw Socket connected to a host and port.
  #
  # @param [String] host hostname (e.g., DNS, mDNS, "localhost" name)
  # @param [Integer] port the port that the server listens to
  # @param [Number] timeout number of seconds to wait for the connection to
  #   succeed
  # @return [Socket] the raw socket
  def self.raw_socket(host, port, timeout = 30)
    Addrinfo.foreach host, port, nil, :STREAM, nil,
                     Socket::AI_NUMERICSERV do |info|
      begin
        return info.connect
      rescue StandardError
        # Try the next address.
      end
    end
    nil
  end
end
