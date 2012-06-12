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

        requires_approval = args.delete(:requires_approval) || args.delete('requires_approval')
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

        message = args.delete(:approval_message) || args.delete('approval_message')

        Resque.enqueue_to(:approval_required, self, args)

        id = Resque.size(:approval_required) - 1

        if message
          key = Resque.encode(:id => id, :approval_message => message)
        else
          key = Resque.encode(:id => id)
        end

        job = Resque.peek(:approval_required, id)
        value = Resque.encode(job)

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
    end
  end
end
