module StaticSite
  class ParallelProcessor
    DEFAULT_THREAD_COUNT = 4

    def initialize(items, thread_count: DEFAULT_THREAD_COUNT)
      @items = items.to_a
      @thread_count = [thread_count, @items.size].min
    end

    def process(&block)
      return if @items.empty?
      return @items.each(&block) if @thread_count <= 1

      queue = Queue.new
      @items.each { |item| queue << item }
      @thread_count.times { queue << :done }

      threads = @thread_count.times.map do
        Thread.new do
          while (item = queue.pop) != :done
            block.call(item)
          end
        end
      end

      threads.each(&:join)
    end
  end
end
