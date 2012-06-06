# resque-approval

A Resque plugin allowing jobs to be sent to a temporary queue to await approval.
Once the job is approved, it is placed on its normal queue.

## Installation

Add this line to your application's Gemfile:

    gem 'resque-approval'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install resque-approval

## Usage

To enable approval holding for a job class, simply extend that class with
Resque::Plugins::Approval, like so:

```ruby
class Job
  extend Resque::Plugins::Approval

  @queue = 'dummy'

  def self.perform
    # ...
  end
end
```

Then, when you want to queue up a job of that class, add a couple special
arguments to your job:

```ruby
Resque.enqueue(Job, :requires_approval => true, :approval_message => 'Test')
```

:requires_approval tells resque-approval to put your job in a special queue to
wait for approval.  If its missing or false, your job is placed in its default
queue.

:approval_message is an optional message you can reference later.

To get a list of pending jobs, call Resque::Plugins::Approval.pending_job_keys.
This will return a list in first-in, first-out order.  Each entry contains an id
and any message you may have specified when enqueueing the job.

To approve a job:
```ruby
Job.approve(key)
```
where key is an entry from the list returned by pending_job_keys.  This will
move the job from the approval_required queue to the default queue for that job.

To reject a job:
```ruby
Job.reject(key)
```
This will delete the job from the approval_required queue, but will not move it
to the job's default queue.  This effectively drops the job from the system.

## Example

A sample session using the Job class above might look like this:

```ruby
# Queue up a job with a message.
Resque.enqueue(Job, :requires_approval => true, :approval_message => 'Just a test')

# Queue up a job without a message.
Resque.enqueue(Job, :requires_approval => true)

# List the ids and messages.
pending_actions = Resque::Plugins::Approval.pending_job_keys
pending_actions.each do |action|
  puts "id: #{action['id'], message: #{action['approval_message']}"
end

# Approve the first job...
Job.approve(pending_actions[0])

# But reject the second
Job.reject(pending_actions[1])
```
## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
