require 'resque-approval/version'
require 'resque'

module Resque
  module Plugins
    module Approval
      def self.pending_job_keys
        keys = Resque.redis.hkeys('pending_jobs')
        keys.map! { |key| JSON.parse(key) }
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
          key = {:id => id, :approval_message => message}.to_json
        else
          key = { :id => id }.to_json
        end

        job = Resque.peek(:approval_required, id)
        value = job.to_json

        Resque.redis.hset('pending_jobs', key, value)
      end

      def approve(key)
        value = Resque.redis.hget('pending_jobs', key)

        return false if value.nil?

        job = JSON.parse(value)

        Resque.redis.hdel('pending_jobs', key)
        Resque.redis.lrem('queue:approval_required', 1, job.to_json)
        Resque.push(Resque.queue_from_class(self), job)

        true
      end

      def reject(key)
        value = Resque.redis.hget('pending_jobs', key)

        return false if value.nil?

        job = JSON.parse(value)

        Resque.redis.hdel('pending_jobs', key)
        Resque.redis.lrem('queue:approval_required', 1, job.to_json)

        true
      end
    end
  end
end
