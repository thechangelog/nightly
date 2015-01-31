def development?
  ENV["NIGHTLY_ENV"] == "development"
end

def with_cache name, &block
  if !development?
    puts "skipping cache!"
    return block.call
  end

  cache_file = "#{name}.cache"

  if File.exists? cache_file
    puts "cache exists! #{cache_file}"
    File.open cache_file do |file|
      return Marshal.load file
    end
  else
    puts "no cache! #{cache_file}"
    results = block.call

    File.open cache_file, "w" do |file|
      Marshal.dump results, file
    end

    results
  end
end
