require 'resque-approval/version'
require 'resque'

module Resque
  module Plugins
    module Approval
      def self.pending_job_keys
        keys = Resque.redis.hkeys('pending_jobs')
        keys.map! { |key| Resque.decode(key) }
        keys.sort! { |a, b| a['id'] <=> b['id'] }
      end

      def before_enqueue_approval(*args)
        args = args[0] || {}

        requires_approval = extract_value(args, :requires_approval)
        if requires_approval
          enqueue_for_approval(args)
          allow_enqueue = false
        else
          allow_enqueue = true
        end

        allow_enqueue
      end

      def before_delayed_enqueue(args)
        key = extract_value(args, :approval_key)
        Resque.redis.hdel('pending_jobs', key)
      end

      def enqueue_for_approval(*args)
        args = args[0] || {}

        message = extract_value(args, :approval_message)
        timeout = extract_value(args, :approval_timeout)

        id = Resque.redis.hlen('pending_jobs')
        key = build_key(id, message, timeout)

        if timeout.kind_of?(Numeric) && timeout > 0 && Resque.respond_to?(:enqueue_in)
          approval_args = args.merge(:approval_key => key)
          Resque.enqueue_in(timeout, self, approval_args)

          queue = Resque.queue_from_class(self)
          value = build_value(queue, approval_args)
        else
          Resque.enqueue_to(:approval_required, self, args)

          value = build_value(nil, args)
        end

        Resque.redis.hset('pending_jobs', key, value)
      end

      def approve(key)
        job = remove_from_pending(key)

        return false if job.nil?

        Resque.push(Resque.queue_from_class(self), job)

        true
      end

      def reject(key)
        !!remove_from_pending(key)
      end

      def remove_from_pending(key)
        value = Resque.redis.hget('pending_jobs', key)

        return if value.nil?

        encoded_job = value
        job = Resque.decode(value)

        Resque.redis.hdel('pending_jobs', key)

        decoded_key = Resque.decode(key)
        if decoded_key.has_key? 'approval_timeout'
          Array(Resque.redis.keys("delayed:*")).each do |key|
            destroyed = Resque.redis.lrem(key, 1, encoded_job)
            break if destroyed > 0
          end
        else
          Resque.redis.lrem('queue:approval_required', 1, encoded_job)
        end

        job
      end

      private

      def extract_value(args, key)
        args.delete(key.to_sym) || args.delete(key.to_s)
      end

      def build_key(id, message, timeout = nil)
        key = { :id => id }

        key.merge!(:approval_message => message) if message
        key.merge!(:approval_timeout => timeout) if timeout

        Resque.encode(key)
      end

      def build_value(queue = nil, *args)
        value = { :class => self.to_s, :args => args }

        value.merge!(:queue => queue) if queue

        Resque.encode(value)
      end
    end
  end
end
