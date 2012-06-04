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

  describe ".before_enqueue_approval" do
    context "when a job requires approval" do
      it "calls enqueue_for_approval" do
        Job.should_receive(:enqueue_for_approval).with()
        Resque.enqueue(Job, :requires_approval => true)
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
      value = '{"class":"Job","args":[]}'

      Resque.redis.hget('pending_jobs', key).should == value
    end
  end
end
