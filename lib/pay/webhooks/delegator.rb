module Pay
  module Webhooks
    class Delegator
      attr_reader :backend

      def initialize
        @backend = ActiveSupport::Notifications
      end

      # Configure DSL
      def configure(&block)
        raise ArgumentError, "must provide a block" unless block
        block.arity.zero? ? instance_eval(&block) : yield(self)
      end

      # Subscribe to specific events
      def subscribe(name, callable = nil, &block)
        callable ||= block
        backend.subscribe to_regexp(name), NotificationAdapter.new(callable)
      end

      # Listen to all events
      def all(callable = nil, &block)
        callable ||= block
        subscribe nil, callable
      end

      # Unsubscribe
      def unsubscribe(name)
        backend.unsubscribe name_with_namespace(name)
      end

      # Called to process an event
      def instrument(event:, type:)
        backend.instrument name_with_namespace(type), event
      end

      def listening?(type)
        backend.notifier.listening? name_with_namespace(type)
      end

      # Strips down to event data only
      class NotificationAdapter
        def initialize(subscriber)
          @subscriber = subscriber
        end

        def call(*args)
          payload = args.last
          @subscriber.call(payload)
        end
      end

      private

      def to_regexp(name)
        %r{^#{Regexp.escape name_with_namespace(name)}}
      end

      def name_with_namespace(name, delimiter: ".")
        [:pay, name].join(delimiter)
      end
    end
  end
end
