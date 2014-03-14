require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'minitest/autorun'
require 'minitest/spec'

require 'simplecov'
SimpleCov.start


$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'ws_sync_client'

require 'net/http'

# Launch a test WebSockets server and wait until it starts.
module RunServerInMinitest
  def before_setup
    super
    @_server_pid = Process.spawn 'bundle exec test/fixtures/ws_server.rb'
    Process.detach @_server_pid

    loop do
      begin
        response = Net::HTTP.get_response URI.parse('http://localhost:9969')
        break if response.kind_of?(Net::HTTPSuccess)
      rescue EOFError
        break
      rescue SystemCallError
        sleep 0.1
      end
    end
  end

  def after_teardown
    Process.kill 'TERM', @_server_pid
    super
  end

  def server_root_url
    "ws://localhost:9969"
  end
end
class MiniTest::Test
  include RunServerInMinitest
end


class MiniTest::Test
end
