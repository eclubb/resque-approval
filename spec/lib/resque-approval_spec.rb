require 'spec_helper'

class Job
  extend Resque::Plugins::Approval

  @queue = 'dummy'

  def self.perform
  end
end

describe "Resque::Plugins::Approval" do
  before do
    Resque.remove_queue(:dummy)
    Resque.remove_queue(:approval_required)
    Resque.redis.del('pending_jobs')
    Resque.reset_delayed_queue
  end

  it "is a valid Resque plugin" do
    expect { Resque::Plugin.lint(Resque::Plugins::Approval) }.not_to raise_error
  end

  describe "#pending_job_keys" do
    it "lists keys (ordered by id) for all jobs that are waiting for approval" do
      Job.enqueue_for_approval
      Job.enqueue_for_approval(:approval_timeout => 10)
      Job.enqueue_for_approval(:approval_message => 'test message')

      keys = [{ 'id' => 0 },
              { 'id' => 1, 'approval_timeout' => 10 },
              { 'id' => 2, 'approval_message' => 'test message' }]
      expect(Resque::Plugins::Approval.pending_job_keys).to eq(keys)
    end
  end

  describe ".before_enqueue_approval" do
    context "when a job requires approval" do
      it "calls enqueue_for_approval" do
        expect(Job).to receive(:enqueue_for_approval).with({})
        Resque.enqueue(Job, :requires_approval => true)
      end
    end

    context "when a job does not require approval" do
      it "does not call enqueue_for_approval" do
        expect(Job).not_to receive(:enqueue_for_approval)
        Resque.enqueue(Job)
      end
    end
  end

  describe ".enqueue_for_approval" do
    it "adds the job to the appoval queue" do
      Job.enqueue_for_approval
      expect(Resque.size(:approval_required)).to eq(1)
    end

    it "does not add the job to the dummy queue" do
      Job.enqueue_for_approval
      expect(Resque.size(:dummy)).to eq(0)
    end

    it "adds an entry to the 'pending_jobs' hash" do
      Job.enqueue_for_approval

      key = '{"id":0}'
      value = '{"class":"Job","args":[{}]}'

      expect(Resque.redis.hget('pending_jobs', key)).to eq(value)
    end

    context "with an approval message" do
      it "includes the message in the 'pending_jobs' hash entry" do
        Job.enqueue_for_approval(:approval_message => 'test message')

        key = '{"id":0,"approval_message":"test message"}'
        value = '{"class":"Job","args":[{}]}'

        expect(Resque.redis.hget('pending_jobs', key)).to eq(value)
      end
    end

    context "with a timeout" do
      it "includes the timeout in the 'pending_jobs' hash entry" do
        Job.enqueue_for_approval(:approval_timeout => 10)

        key = '{"id":0,"approval_timeout":10}'
        args = { :approval_key => key }
        value = { :class => Job, :args => [args], :queue => :dummy }
        value = Resque.encode(value)

        expect(Resque.redis.hget('pending_jobs', key)).to eq(value)
      end

      it "schedules the job" do
        expect(Resque.count_all_scheduled_jobs).to eq(0)

        Job.enqueue_for_approval(:approval_timeout => 10)

        expect(Resque.count_all_scheduled_jobs).to eq(1)
      end

      it "does not add the job to the appoval queue" do
        Job.enqueue_for_approval(:approval_timeout => 10)
        expect(Resque.size(:approval_required)).to eq(0)
      end
    end

    context "with a disabled timeout" do
      it "includes the timeout in the 'pending_jobs' hash entry" do
        Job.enqueue_for_approval(:approval_timeout => 0)

        key = '{"id":0,"approval_timeout":0}'
        value = { :class => Job, :args => [{}] }
        value = Resque.encode(value)

        expect(Resque.redis.hget('pending_jobs', key)).to eq(value)
      end

      it "does not schedule the job" do
        expect(Resque.count_all_scheduled_jobs).to eq(0)

        Job.enqueue_for_approval(:approval_timeout => 0)

        expect(Resque.count_all_scheduled_jobs).to eq(0)
      end

      it "adds the job to the appoval queue" do
        Job.enqueue_for_approval(:approval_timeout => 0)
        expect(Resque.size(:approval_required)).to eq(1)
      end
    end
  end

  describe ".approve" do
    it "calls .remove_from_pending" do
      key = '{"id":0}'

      expect(Job).to receive(:remove_from_pending).with(key)
      Job.approve(key)
    end

    context "without a timeout" do
      it "adds  the job to its normal queue" do
        key = '{"id":0}'

        Job.enqueue_for_approval
        Job.approve(key)

        expect(Resque.size(:dummy)).to eq(1)
      end
    end

    context "with a timeout" do
      it "adds  the job to its normal queue" do
        key = '{"id":0,"approval_timeout":10}'

        Job.enqueue_for_approval(:approval_timeout => 10)
        Job.approve(key)

        expect(Resque.size(:dummy)).to eq(1)
      end
    end

    it "returns false when key can not be found" do
      expect(Job.approve('bad key')).to eq(false)
    end
  end

  describe ".reject" do
    it "calls .remove_from_pending" do
      key = '{"id":0}'

      expect(Job).to receive(:remove_from_pending).with(key)
      Job.reject(key)
    end

    it "does not add  the job to its normal queue" do
      key = '{"id":0}'

      Job.enqueue_for_approval
      Job.reject(key)

      expect(Resque.size(:dummy)).to eq(0)
    end

    it "returns false when key can not be found" do
      expect(Job.reject('bad key')).to eq(false)
    end
  end

  describe ".remove_from_pending" do
    context "without a timeout" do
      it "deletes the job from the approval queue" do
        key = '{"id":0}'

        Job.enqueue_for_approval
        Job.remove_from_pending(key)

        expect(Resque.size(:approval_required)).to eq(0)
      end
    end

    context "with a timeout" do
      it "unschedules the job" do
        key = '{"id":0,"approval_timeout":10}'

        Job.enqueue_for_approval(:approval_timeout => 10)

        expect(Resque.count_all_scheduled_jobs).to eq(1)

        Job.remove_from_pending(key)

        expect(Resque.count_all_scheduled_jobs).to eq(0)
      end
    end

    it "deletes the entry in the 'pending_jobs' hash" do
      key = '{"id":0}'

      Job.enqueue_for_approval
      Job.remove_from_pending(key)

      expect(Resque.redis.hget('pending_jobs', key)).to be_nil
    end

    it "returns job when key can be found" do
      key = '{"id":0}'
      job = { 'class' => 'Job', 'args' => [{}] }

      Job.enqueue_for_approval
      job = expect(Job.remove_from_pending(key)).to eq(job)
    end

    it "returns nil when key can not be found" do
      expect(Job.remove_from_pending('bad key')).to eq(nil)
    end
  end

  describe ".extract_value" do
    context "when key is a symbol" do
      it "deletes and returns value by symbol-referenced key" do
        hash = { :key => 1 }

        expect(Job.send(:extract_value, hash, :key)).to eq(1)
        expect(hash).to eq({})
      end

      it "deletes and returns value by string-referenced key" do
        hash = { :key => 1 }

        expect(Job.send(:extract_value, hash, 'key')).to eq(1)
        expect(hash).to eq({})
      end
    end

    context "when key is a string" do
      it "deletes and returns value by symbol-referenced key" do
        hash = { 'key' => 1 }

        expect(Job.send(:extract_value, hash, :key)).to eq(1)
        expect(hash).to eq({})
      end

      it "deletes and returns value by string-referenced key" do
        hash = { 'key' => 1 }

        expect(Job.send(:extract_value, hash, 'key')).to eq(1)
        expect(hash).to eq({})
      end
    end
  end
end
