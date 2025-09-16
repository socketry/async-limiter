# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "async/limiter"

describe Async::Limiter::Generic do
	it "provides basic statistics" do
		limiter = Async::Limiter::Generic.new
		statistics = limiter.statistics
		
		expect(statistics).to be_a(Hash)
		expect(statistics[:timing]).to be_a(Hash)
		expect(statistics[:timing][:name]).to be == "None"
	end
end

describe Async::Limiter::Limited do
	let(:limiter) {Async::Limiter::Limited.new(3)}
	
	it "provides limited limiter statistics" do
		statistics = limiter.statistics
		
		expect(statistics).to be_a(Hash)
		expect(statistics[:limit]).to be == 3
		expect(statistics[:count]).to be == 0
		expect(statistics[:timing]).to be_a(Hash)
	end
	
	it "tracks acquisition count" do
		limiter.acquire  # 1/3
		limiter.acquire  # 2/3
		
		statistics = limiter.statistics
		
		expect(statistics[:limit]).to be == 3
		expect(statistics[:count]).to be == 2
	end
	
	it "updates statistics after release" do
		resource1 = limiter.acquire  # 1/3
		resource2 = limiter.acquire  # 2/3
		
		expect(limiter.statistics[:count]).to be == 2
		
		limiter.release(resource1)  # 1/3
		
		expect(limiter.statistics[:count]).to be == 1
		
		limiter.release(resource2)  # 0/3
		
		expect(limiter.statistics[:count]).to be == 0
	end
	
	it "is thread-safe" do
		require "async"
		
		Async do
			results = []
			
			# Start tasks that continuously acquire/release
			acquire_tasks = 3.times.map do
				Async do
					5.times do
						resource = limiter.acquire(timeout: 0.1)
						if resource
							limiter.release(resource)
						end
					end
				end
			end
			
			# Start task that continuously reads statistics
			stats_task = Async do
				10.times do
					stats = limiter.statistics
					results << stats
					expect(stats[:count]).to be >= 0
					expect(stats[:count]).to be <= stats[:limit]
				end
			end
			
			[*acquire_tasks, stats_task].each(&:wait)
			
			expect(results.size).to be == 10
			expect(limiter.statistics[:count]).to be == 0  # All released at end
		end
	end
end

describe Async::Limiter::Queued do
	it "provides queued limiter statistics" do
		require "async/queue"
		
		queue = Async::Queue.new
		limiter = Async::Limiter::Queued.new(queue)
		statistics = limiter.statistics
		
		expect(statistics).to be_a(Hash)
		expect(statistics[:waiting]).to be_a(Integer)
		expect(statistics[:available]).to be_a(Integer)
		expect(statistics[:timing]).to be_a(Hash)
	end
	
	it "tracks available resources" do
		require "async/queue"
		
		queue = Async::Queue.new
		limiter = Async::Limiter::Queued.new(queue)
		
		# Initially empty
		expect(limiter.statistics[:available]).to be == 0
		
		# Add resources
		limiter.release("worker1")
		limiter.release("worker2")
		
		expect(limiter.statistics[:available]).to be == 2
		
		# Consume one resource
		resource = limiter.acquire(timeout: 0)
		expect(resource).to be == "worker1"
		expect(limiter.statistics[:available]).to be == 1
		
		# Return resource
		limiter.release(resource)
		expect(limiter.statistics[:available]).to be == 2
	end
end

describe "Timing Strategy Statistics" do
	it "provides None timing statistics" do
		statistics = Async::Limiter::Timing::None.statistics
		
		expect(statistics).to be_a(Hash)
		expect(statistics[:name]).to be == "None"
	end
	
	it "provides FixedWindow timing statistics" do
		window = Async::Limiter::Timing::FixedWindow.new(
			1.0, 
			Async::Limiter::Timing::Burst::Greedy, 
			5
		)
		
		statistics = window.statistics
		
		expect(statistics).to be_a(Hash)
		expect(statistics[:name]).to be == "FixedWindow"
		expect(statistics[:window_duration]).to be == 1.0
		expect(statistics[:window_limit]).to be == 5
		expect(statistics[:burst]).to be == {name: "Greedy"}
	end
	
	it "provides SlidingWindow timing statistics" do
		limiter = Async::Limiter::Generic.new(timing: Async::Limiter::Timing::SlidingWindow.new(
			1.0, 
			Async::Limiter::Timing::Burst::Greedy, 
			5
		))
		
		statistics = limiter.statistics
		
		expect(statistics).to be_a(Hash)
		expect(statistics[:timing][:name]).to be == "SlidingWindow"
		expect(statistics[:timing][:window_duration]).to be == 1.0
		expect(statistics[:timing][:window_limit]).to be == 5
		expect(statistics[:timing][:current_window_count]).to be_a(Integer)
		expect(statistics[:timing][:window_utilization_percentage]).to be_a(Float)
		expect(statistics[:timing][:burst]).to be == {name: "Greedy"}
	end
	
	it "provides LeakyBucket timing statistics" do
		limiter = Async::Limiter::Generic.new(timing: Async::Limiter::Timing::LeakyBucket.new(2.0, 10.0))
		
		statistics = limiter.statistics
		
		expect(statistics).to be_a(Hash)
		expect(statistics[:timing][:name]).to be == "LeakyBucket"
		expect(statistics[:timing][:current_level]).to be_a(Float)
		expect(statistics[:timing][:maximum_capacity]).to be == 10.0
		expect(statistics[:timing][:leak_rate]).to be == 2.0
		expect(statistics[:timing][:available_capacity]).to be_a(Float)
		expect(statistics[:timing][:utilization_percentage]).to be_a(Float)
	end
	
	it "provides Burst::Smooth statistics" do
		statistics = Async::Limiter::Timing::Burst::Smooth.statistics
		
		expect(statistics).to be_a(Hash)
		expect(statistics[:name]).to be == "Smooth"
	end
	
	it "provides Ordered timing statistics with delegation" do
		# Use FixedWindow since LeakyBucket statistics doesn't work yet
		window = Async::Limiter::Timing::FixedWindow.new(1.0, Async::Limiter::Timing::Burst::Greedy, 5)
		ordered = Async::Limiter::Timing::Ordered.new(window)
		
		statistics = ordered.statistics
		
		expect(statistics).to be_a(Hash)
		expect(statistics[:name]).to be == "FixedWindow"
		expect(statistics[:ordered]).to be == true  # Added by Ordered wrapper
	end
end