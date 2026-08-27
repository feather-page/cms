require "rails_helper"

RSpec.describe StaticSite::ParallelProcessor do
  describe "#process" do
    it "processes all items" do
      items = [1, 2, 3, 4, 5]
      results = []
      mutex = Mutex.new

      described_class.new(items, thread_count: 2).process do |item|
        mutex.synchronize { results << item }
      end

      expect(results.sort).to eq([1, 2, 3, 4, 5])
    end

    it "handles empty collections" do
      results = []

      described_class.new([], thread_count: 2).process do |item|
        results << item
      end

      expect(results).to be_empty
    end

    it "handles single item" do
      results = []

      described_class.new([42], thread_count: 4).process do |item|
        results << item
      end

      expect(results).to eq([42])
    end

    it "limits thread count to item count" do
      thread_ids = []
      mutex = Mutex.new

      described_class.new([1, 2], thread_count: 10).process do |_item|
        mutex.synchronize { thread_ids << Thread.current.object_id }
        sleep(0.01)
      end

      expect(thread_ids.uniq.size).to be <= 2
    end

    it "uses sequential processing when thread_count is 1" do
      items = [1, 2, 3]
      results = []

      described_class.new(items, thread_count: 1).process do |item|
        results << item
      end

      expect(results).to eq([1, 2, 3])
    end
  end
end
