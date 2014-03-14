require 'helper'

describe 'WsSync' do
  before do
    @ws = WsSyncClient.new server_root_url + "/hello/world?answer=42"
  end
  after do
    @ws.close
  end

  describe '#recv_frame' do
    it 'receives the handshake' do
      parsed = JSON.parse @ws.recv_frame
      parsed.must_equal 'handshake' => 'completed', 'path' => '/hello/world',
          'query' => 'answer=42', 'host' => 'localhost:9969'
    end
  end

  describe '#send_frame' do
    it 'completes a handshake/echo cycle' do
      parsed = JSON.parse @ws.recv_frame
      parsed['handshake'].must_equal 'completed'

      @ws.send_frame JSON.dump(cmd: 'echo', seq: 1, data: 'Hello world!')
      parsed = JSON.parse @ws.recv_frame
      parsed.must_equal 'status' => 'ok', 'seq' => 1, 'data' => 'Hello world!'
    end

    it 'completes a handshake/echo cycle with a large payload' do
      parsed = JSON.parse @ws.recv_frame
      parsed['handshake'].must_equal 'completed'

      data = 'Hello world!\n' * 10_000
      @ws.send_frame JSON.dump(cmd: 'echo', seq: 1, data: data)
      parsed = JSON.parse @ws.recv_frame
      parsed.must_equal 'status' => 'ok', 'seq' => 1, 'data' => data
    end

    it 'completes a few synchronous handshake/echo cycles' do
      parsed = JSON.parse @ws.recv_frame
      parsed['handshake'].must_equal 'completed'

      1.upto 32 do |seq|
        @ws.send_frame JSON.dump(cmd: 'echo', seq: seq, data: 'Hello world!')
        parsed = JSON.parse @ws.recv_frame
        parsed.must_equal 'status' => 'ok', 'seq' => seq,
                          'data' => 'Hello world!'
      end
    end

    it 'completes a few asynchronous handshake/echo cycles' do
      parsed = JSON.parse @ws.recv_frame
      parsed['handshake'].must_equal 'completed'

      1.upto 32 do |seq|
        @ws.send_frame JSON.dump(cmd: 'echo', seq: seq, data: 'Hello world!')
      end

      1.upto 32 do |seq|
        parsed = JSON.parse @ws.recv_frame
        parsed.must_equal 'status' => 'ok', 'seq' => seq,
                          'data' => 'Hello world!'
      end
    end
  end
end
