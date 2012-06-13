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

      def enqueue_for_approval(*args)
        args = args[0] || {}

        message = extract_value(args, :approval_message)

        id = Resque.redis.hlen('pending_jobs')
        key = build_key(id, message)
        value = build_value(nil, args)

        Resque.enqueue_to(:approval_required, self, args)
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
        Resque.redis.lrem('queue:approval_required', 1, encoded_job)

        job
      end

      private

      def extract_value(args, key)
        args.delete(key.to_sym) || args.delete(key.to_s)
      end

      def build_key(id, message)
        key = { :id => id }

        key.merge!(:approval_message => message) if message

        Resque.encode(key)
      end

      def build_value(queue = nil, *args)
        value = { :class => self.to_s, :args => args }

        Resque.encode(value)
      end
    end
  end
end
