# frozen_string_literal: true
module WorkStateTransition
  class BaseNotification < WorkActivityNotification
    private

      def wait_time
        if Rails.env.development?
          0
        else
          super
        end
      end
  end
end
