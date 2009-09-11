require 'yaml'
require 'cldr'

module Spider; module I18n
    
    class CLDR < Provider
        
        def initialize(locale)
            @locale = locale
            @cldr = ::CLDR::Object.new(:locale => Locale::Object.new(locale))

        end

        def localize_date_time(locale, object, format = :default, options={})
            options[:calendar] ||= 'gregorian'
            
            if (format == :default)
                format = @cldr.calendar.dateformat_defaults[options[:calendar]]
            end
            
            time_format = nil
            date_format = nil
            format_string = nil
            if (object.respond_to?(:sec) && !options[:no_time])
                time_format = @cldr.calendar.timeformats[options[:calendar].to_sym][format.to_s].dup
            end
            if (object.is_a?(Date))
                date_format = @cldr.calendar.dateformats[options[:calendar].to_sym][format.to_s].dup
            end
            if (date_format && time_format)
                dt_f = @cldr.calendar.datetimeformats[options[:calendar].to_s]
                format_string = dt_f.sub('{1}', date_format).sub('{0}', time_format)
            else
                format_string = date_format ? date_format : time_format
            end

            # FIXME: handle more efficiently
            d = ['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat']
            obj_d = d[object.wday]
            days = @cldr.calendar.days[options[:calendar].to_sym]
            months = @cldr.calendar.months[options[:calendar].to_sym]
            replacements = [
                [/y{1,4}/, '%Y'], # year  don't use two digits year, they cause confusion [/y{1,2}/, '%y']
                [/M{5}/, months[:narrow][object.month.to_s]], [/M{4}/, months[:wide][object.month.to_s]], #month
                [/M{3}/, months[:abbreviated][object.month.to_s]], [/M{1,2}/, '%m'], 
                [/L{5}/, months[:narrow][object.month.to_s]], [/L{4}/, months[:wide][object.month.to_s]], #month
                [/L{3}/, months[:abbreviated][object.month.to_s]], [/L{1,2}/, '%m'], 
                [/E{5}/, days[:narrow][obj_d]], [/E{4}/, days[:wide][obj_d]], [/E{1,3}/, days[:abbreviated][obj_d]], #day of the week
                [/e{1,5}/, '%w'], #day of the week (numeric)
                [/d{1,2}/, '%d'], # day of the month
                [/h{1,2}/, '%I'], [/H{1,2}/, '%H'], [/a/, '%p'], #hour
                [/m{1,2}/, '%M'], [/s{1,2}/, '%S'], # seconds
                [/z{1,4}/, '%Z'], [/Z{1,4}/, '%Z'], [/V{1,4}/, '%Z'] # time zone
            ]
            format_string = mgsub(format_string, replacements)

            if (time_format)
                am = @cldr.calendar.am[options[:calendar].to_s]
                pm = @cldr.calendar.pm[options[:calendar].to_s]
                format_string.gsub!(/%p/, object.hour < 12 ? am : pm) if object.respond_to? :hour
            end
            object.strftime(format_string)
        end
        
        # FIXME: add extended format handling like in localize
        def parse_dt(locale, string, format = :default, options = {})
            options[:calendar] ||= 'gregorian'
            
            if (format == :default)
                format = @cldr.calendar.dateformat_defaults[options[:calendar]]
            end
            time_format = @cldr.calendar.timeformats[options[:calendar].to_sym][format.to_s].dup
            date_format = @cldr.calendar.dateformats[options[:calendar].to_sym][format.to_s].dup
            if (options[:return] == :datetime)
                dt_f = @cldr.calendar.datetimeformats[options[:calendar].to_s]
                format_string = dt_f.sub('{1}', date_format).sub('{0}', time_format)
                klass = DateTime
            elsif (options[:return] == :date)
                format_string = date_format
                klass = Date
            end
            replacements = [
                [/y{1,4}/, '%Y'], # year      don't use two digits year [/y{1,2}/, '%y'],
                [/M{1,5}/, '%m'],
                [/L{1,5}/, '%m'],
                [/E{1,5}/, ''], #day of the week
                [/e{1,5}/, '%w'], #day of the week (numeric)
                [/d{1,2}/, '%d'], # day of the month
                [/h{1,2}/, '%I'], [/H{1,2}/, '%H'], [/a/, '%p'], #hour
                [/m{1,2}/, '%M'], [/s{1,2}/, '%S'], # seconds
                [/z{1,4}/, '%Z'], [/Z{1,4}/, '%Z'], [/V{1,4}/, '%Z'] # time zone
            ]
            format_string = mgsub(format_string, replacements)
            klass.strptime(string, format_string)
        end
        
        
        def prepare_format_string(obj, string)
 
        end
        
        
        def mgsub(string, key_value_pairs)
            regexp_fragments = key_value_pairs.collect { |k,v| k }
            string.gsub( 
            Regexp.union(*regexp_fragments)) do |match|
                key_value_pairs.detect{|k,v| k =~ match}[1]
            end
        end
        
    end
    
end; end