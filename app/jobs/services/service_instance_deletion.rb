module VCAP::CloudController
  module Jobs
    module Services
      class ServiceInstanceDeletion < VCAP::CloudController::Jobs::CCJob
        attr_accessor :guid

        def initialize(guid)
          @guid = guid
        end

        def perform
          logger = Steno.logger('cc.background')
          logger.info("Deleting model class 'ServiceInstance' with guid '#{guid}'")
          service_instance = ServiceInstance.find(guid: @guid)

          return if service_instance.nil?
          begin
            service_instance.destroy
          rescue
            service_instance.save_with_operation(
              last_operation: {
                state: 'failed',
              }
            )
            raise
          end
        end

        def job_name_in_configuration
          :model_deletion
        end

        def max_attempts
          1
        end
      end
    end
  end
end
