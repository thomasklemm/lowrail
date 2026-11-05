# Redefines change, known_period and wrap_with_time_zone from s81new's time_with_zone.rb after boot.
class ActiveSupport::TimeWithZone
    def change(options)
      if options[:zone] && options[:offset]
        raise ArgumentError, "Can't change both :offset and :zone at the same time: #{options.inspect}"
      end

      new_time = time.change(options)

      if options[:zone]
        new_zone = ::Time.find_zone(options[:zone])
      elsif options[:offset]
        new_zone = ::Time.find_zone(new_time.utc_offset)
      end

      new_zone ||= time_zone
      periods = new_zone.periods_for_local(new_time)

      self.class.new(nil, new_zone, new_time, known_period(periods, new_time))
    end
    private
      def known_period(periods, time)
        if periods.include?(period)
          period
        elsif periods.one? && time.is_a?(::Time)
          # TZInfo reads a DateTime by its Julian day, which needn't match the civil fields the constructor looks up.
          periods.first
        end
      end
      def wrap_with_time_zone(time)
        if time.acts_like?(:time)
          periods = time_zone.periods_for_local(time)
          self.class.new(nil, time_zone, time, known_period(periods, time))
        elsif time.is_a?(Range)
          wrap_with_time_zone(time.begin)..wrap_with_time_zone(time.end)
        else
          time
        end
      end
end
