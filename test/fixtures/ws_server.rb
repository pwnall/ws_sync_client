#!/usr/bin/env ruby

# Tiny WebSocket test server for WsSync.
#
#
#
# Manual testing sequence for this test server:
#
# $ npm install -g ws
# $ wscat --connect ws://localhost:9969/hello/world?ohai
# connected (press CTRL+C to quit)
#
# < {"handshake":"completed","path":"/hello/world","query":"ohai","host":"localhost:9969"}
# > {"cmd":"echo", "seq": 666, "data": "Boom headshot!"}
#
# < {"status":"ok","seq":666,"data":"Boom headshot!"}
# > {"cmd":"echo ", "seq": 666, "data": "Boom headshot!"}
#
# < {"status":"error","seq":666,"reason":"unknown command"}
# (press Ctrl+C)

require 'json'
require 'rubygems'
require 'em-websocket'

EM.run do
  EM::WebSocket.run host: '0.0.0.0', port: 9969 do |ws|
    ws.onopen do |handshake|
      ws.send JSON.dump(handshake: 'completed', path: handshake.path,
                        query: handshake.query_string,
                        host: handshake.headers['Host'])
    end

    ws.onmessage do |message|
      command = JSON.parse message
      case command['cmd']
      when 'echo'
        response = { status: 'ok', seq: command['seq'], data: command['data'] }
      when 'close'
        ws.close command['code'], command['reason']
        response = nil
      else
        response = { status: 'error', seq: command['seq'],
                     reason: 'unknown command' }
      end
      ws.send JSON.dump(response) unless response.nil?
    end

    ws.onclose do
    end
  end
end
