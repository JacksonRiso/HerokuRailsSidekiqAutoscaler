#Variables, to change
jobs_queued_per_server = 1_000 # How many enqueued jobs per server? For example, if 100, then at 200 jobs enqueued, this code will add 1 more server, for a total of 2
reset_when_threshold_met = 100 #When number of enqueued jobs dips below this threshold, return to 1 server
max_servers = 10 # Set a max server amount. Check max Redis connections
heroku_app_name = 'heroku-app-name' # Your heroku app name


count = enqueued_jobs.count
servers_needed = (count / jobs_queued_per_server).round(0) + 1
servers_existent = $redis.get('number_of_worker_servers').to_i
servers_needed = max_servers if servers_needed > max_servers

if servers_needed > servers_existent || count <= 100 && servers_needed != servers_existent
  heroku_service = HerokuService.new(heroku_app_name)
  heroku_service.scale_workers(servers_needed)
  $redis.set('number_of_worker_servers', servers_needed)
end

def enqueued_jobs
  queues = Sidekiq::Queue.all
  queues.each_with_object([]) do |queue, jobs|
    queue.each do |job|
      jobs << job.klass
    end
  end
end


#heroku_service.rb
require 'platform-api'

class HerokuService
  def initialize(app_name)
    @app_name = app_name
    @heroku_client = PlatformAPI.connect_oauth(ENV['HEROKU_API_KEY'])
  end

  def scale_workers(worker_count)
    @heroku_client.formation.update(@app_name, 'worker', { quantity: worker_count })
  rescue StandardError => e
    Rails.logger.error("Failed to scale dynos: #{e.message}")
    nil
  end
end
