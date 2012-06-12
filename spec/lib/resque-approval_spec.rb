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
  end

  it "is a valid Resque plugin" do
    lambda { Resque::Plugin.lint(Resque::Plugins::Approval) }.should_not raise_error
  end

  describe "#pending_job_keys" do
    it "lists keys (ordered by id) for all jobs that are waiting for approval" do
      Job.enqueue_for_approval(:approval_message => 'test message 1')
      Job.enqueue_for_approval
      Job.enqueue_for_approval(:approval_message => 'test message 2')

      keys = [{'id' => 0, 'approval_message' => 'test message 1'},
              {'id' => 1},
              {'id' => 2, 'approval_message' => 'test message 2'}]
      Resque::Plugins::Approval.pending_job_keys.should == keys
    end
  end

  describe ".before_enqueue_approval" do
    context "when a job requires approval (via symbol or string)" do
      it "calls enqueue_for_approval" do
        Job.should_receive(:enqueue_for_approval).twice.with({})
        Resque.enqueue(Job, :requires_approval => true)
        Resque.enqueue(Job, 'requires_approval' => true)
      end
    end

    context "when a job does not require approval" do
      it "does not call enqueue_for_approval" do
        Job.should_not_receive(:enqueue_for_approval)
        Resque.enqueue(Job)
      end
    end
  end

  describe ".enqueue_for_approval" do
    it "adds the job to the appoval queue" do
      Job.enqueue_for_approval
      Resque.size(:approval_required).should == 1
    end

    it "does not add the job to the dummy queue" do
      Job.enqueue_for_approval
      Resque.size(:dummy).should == 0
    end

    it "adds an entry to the 'pending_jobs' hash" do
      Job.enqueue_for_approval()

      key = '{"id":0}'
      value = '{"class":"Job","args":[{}]}'

      Resque.redis.hget('pending_jobs', key).should == value
    end

    context "with an approval message (via symbol)" do
      it "includes the message in the 'pending_jobs' hash entry" do
        Job.enqueue_for_approval(:approval_message => 'symbol test message')

        key = '{"id":0,"approval_message":"symbol test message"}'
        value = '{"class":"Job","args":[{}]}'

        Resque.redis.hget('pending_jobs', key).should == value
      end
    end

    context "with an approval message (via string)" do
      it "includes the message in the 'pending_jobs' hash entry" do
        Job.enqueue_for_approval('approval_message' => 'string test message')

        key = '{"id":0,"approval_message":"string test message"}'
        value = '{"class":"Job","args":[{}]}'

        Resque.redis.hget('pending_jobs', key).should == value
      end
    end
  end

  describe ".approve" do
    it "moves the job from the approval queue to its normal queue" do
      key = '{"id":0}'

      Resque.enqueue(Job, :requires_approval => true)
      Job.approve(key)

      Resque.size(:approval_required).should == 0
      Resque.size(:dummy).should == 1
    end

    it "deletes the entry in the 'pending_jobs' hash" do
      key = '{"id":0}'

      Resque.enqueue(Job, :requires_approval => true)
      Job.approve(key)

      Resque.redis.hget('pending_jobs', key).should be_nil
    end

    it "returns false when key can not be found" do
      Job.approve('bad key').should == false
    end
  end

  describe ".reject" do
    it "calls .remove_from_pending" do
      key = '{"id":0}'

      Job.should_receive(:remove_from_pending).with(key)
      Job.reject(key)
    end

    it "does not add  the job to its normal queue" do
      key = '{"id":0}'

      Resque.enqueue(Job, :requires_approval => true)
      Job.reject(key)

      Resque.size(:dummy).should == 0
    end

    it "returns false when key can not be found" do
      Job.reject('bad key').should == false
    end
  end

  describe ".remove_from_pending" do
    it "deletes the job from the approval queue" do
      key = '{"id":0}'

      Resque.enqueue(Job, :requires_approval => true)
      Job.remove_from_pending(key)

      Resque.size(:approval_required).should == 0
    end

    it "deletes the entry in the 'pending_jobs' hash" do
      key = '{"id":0}'

      Resque.enqueue(Job, :requires_approval => true)
      Job.remove_from_pending(key)

      Resque.redis.hget('pending_jobs', key).should be_nil
    end

    it "returns job when key can be found" do
      key = '{"id":0}'
      job = { 'class' => 'Job', 'args' => [{}] }

      Resque.enqueue(Job, :requires_approval => true)
      job = Job.remove_from_pending(key).should == job
    end

    it "returns nil when key can not be found" do
      Job.remove_from_pending('bad key').should == nil
    end
  end
end
