module Downloads
  class TemporaryFile
    def initialize(file)
      @file = file
    end

    def each
      return enum_for(:each) unless block_given?

      begin
        File.open(@file.path, "rb") do |io|
          while (chunk = io.read(64.kilobytes))
            yield chunk
          end
        end
      ensure
        close
      end
    end

    def close
      @file.close!
    end
  end
end
