# encoding: utf-8
module CarrierWave
  module Workers

    class StoreAsset < Struct.new(:klass, :id, :column)
      include ::Sidekiq::Worker if defined?(::Sidekiq)
      attr_reader :cache_path, :tmp_directory

      def self.perform(*args)
        new(*args).perform
      end

      def perform(*args)
        set_args(*args) if args.present?
        @record = constantized_resource.find id

        if @record.send(:"#{column}_tmp")
          store_directories(@record)
          @record.send :"process_#{column}_upload=", true
          @record.send :"#{column}_tmp=", nil
          File.open(cache_path) { |f| @record.send :"#{column}=", f }
          if @record.save!
            FileUtils.rm_r(tmp_directory, :force => true)
          end
        end
      end


      def set_args(klass, id, column)
        self.klass, self.id, self.column = klass, id, column
      end

      def enqueue(job)
        if @record.respond_to?(:enqueue_callback)
          @record.enqueue_callback(job)
        end
      end

      def before(job)
        if @record.respond_to?(:before_callback)
          @record.before_callback(job)
        end
      end

      def after(job)
        if @record.respond_to?(:after_callback)
          @record.after_callback(job)
        end
      end

      def success(job)
        if @record.respond_to?(:success_callback)
          @record.success_callback(job)
        end
      end

      def error(job, exception)
        if @record.respond_to?(:error_callback)
          @record.error_callback(job, exception)
        end
      end

      def failure
        if @record.respond_to?(:failure_callback)
          @record.failure_callback
        end
      end

      private
      def constantized_resource
        klass.is_a?(String) ? klass.constantize : klass
      end

      def store_directories(record)
        asset, asset_tmp = record.send(:"#{column}"), record.send(:"#{column}_tmp")
        cache_directory  = File.join(asset.root, asset.cache_dir)
        @cache_path      = File.join(cache_directory, asset_tmp)
        @tmp_directory   = File.join(cache_directory, asset_tmp.split("/").first)
      end
    end # StoreAsset

  end # Workers
end # Backgrounder
