require 'resque-approval'

ROOT_PATH = File.expand_path('..', __FILE__)
TMP_PATH = '/tmp'

def start_redis
  puts 'Starting redis for testing at localhost:9736...'
  `redis-server #{ROOT_PATH}/redis-test.conf`
  Resque.redis = 'localhost:9736'
  sleep 0.1
end

def stop_redis
  puts "\nKilling test redis server..."
  %x{
    cat #{TMP_PATH}/redis-test.pid | xargs kill -QUIT
    rm -f #{TMP_PATH}/redis-test-dump.rdb
  }
end

RSpec.configure do |config|
  config.before(:suite) do
    start_redis
  end

  config.after(:suite) do
    stop_redis
  end
end
