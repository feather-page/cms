module StaticSite
  class ParallelProcessor
    DEFAULT_THREAD_COUNT = 4

    def initialize(items, thread_count: DEFAULT_THREAD_COUNT)
      @items = items.to_a
      @thread_count = [thread_count, @items.size].min
    end

    def process(&)
      return if @items.empty?
      return @items.each(&) if @thread_count <= 1

      process_in_parallel(&)
    end

    private

    def process_in_parallel(&)
      queue = build_queue
      threads = spawn_workers(queue, &)
      threads.each(&:join)
    end

    def build_queue
      Queue.new.tap do |queue|
        @items.each { |item| queue << item }
        @thread_count.times { queue << :done }
      end
    end

    def spawn_workers(queue, &block)
      Array.new(@thread_count) { create_worker(queue, &block) }
    end

    def create_worker(queue)
      Thread.new do
        while (item = queue.pop) != :done
          yield(item)
        end
      end
    end
  end
end
