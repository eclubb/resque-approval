require 'rspec'
require 'resque-approval'
require 'resque_scheduler'

def start_redis
  redis_config = <<END
daemonize yes
pidfile #{redis_pid_file}
port #{redis_port}
END

  puts "Starting Redis for testing on port #{redis_port}"
  IO.popen("redis-server -", 'w+') do |server|
    server.write(redis_config)
    server.close_write
  end
  Resque.redis = "localhost:#{redis_port}"

  sleep 0.1 # give Redis time to start

  puts "Redis is running with PID #{redis_pid}"
end

def stop_redis
  if redis_pid
    puts "\nSending TERM signal to Redis (#{redis_pid})"
    Process.kill("TERM", redis_pid)
  end
end

def redis_port
  9736
end

def redis_pid_file
  File.expand_path('../redis-test.pid', __FILE__)
end

def redis_pid
  File.exist?(redis_pid_file) && File.read(redis_pid_file).to_i
end

RSpec.configure do |config|
  config.before(:suite) do
    start_redis
  end

  config.after(:suite) do
    stop_redis
  end
end
