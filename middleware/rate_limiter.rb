module CloudFoundry
  module Middleware
    class RateLimiter
      def initialize(app, default_limit, interval)
        @app = app
        @default_limit = default_limit
        @interval = interval
      end

      def call(env)
        status, headers, body = @app.call(env)
        if env['cf.user_guid']
          request_count = VCAP::CloudController::RequestCount.find_or_create(user_guid: env['cf.user_guid']) do |created_request_count|
            created_request_count.valid_until = Time.now + @interval.minutes
          end

          request_count.db.transaction do
            request_count.lock!
            if request_count.valid_until < Time.now
              request_count.valid_until = Time.now + @interval.minutes
              request_count.count = 0
            end

            request_count.count += 1
            request_count.save
          end

          headers['X-RateLimit-Limit'] = @default_limit.to_s
          headers['X-RateLimit-Reset'] = request_count.valid_until.utc.to_i.to_s
          headers['X-RateLimit-Remaining'] = [0, @default_limit - request_count.count].max.to_s
        end
        [status, headers, body]
      end
    end
  end
end
