require 'resque-approval/version'
require 'resque'

module Resque
  module Plugins
    module Approval
      def before_enqueue_approval(*args)
        args = args[0] || {}

        requires_approval = args.delete(:requires_approval)
        if requires_approval
          enqueue_for_approval(*args)
          allow_enqueue = false
        else
          allow_enqueue = true
        end

        allow_enqueue
      end

      def enqueue_for_approval(*args)
        Resque.enqueue_to(:approval_required, self, *args)

        id = Resque.size(:approval_required) - 1
        key = { :id => id }.to_json

        job = Resque.peek(:approval_required, id)
        value = job.to_json

        Resque.redis.hset('pending_jobs', key, value)
      end
    end
  end
end
