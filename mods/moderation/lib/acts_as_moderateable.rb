module Crabgrass
  module Acts
    module Moderateable
      FLAGS = { :none => 0, :public => 1, :public_requested => 2, :inappropriate => 3, :vetted => 4 }.freeze
      module ClassMethods
        def acts_as_moderateable(options={})
          @@moderation_options = { 
            :column => "moderation_flag",
            :flags => FLAGS
          }.merge(options)
          
          if @@moderation_options[:flags].kind_of?(Array)
            i=0
            @@moderation_options[:flags] = @@moderation_options[:flags].inject({}) do |hsh, flag|
              hsh[flag] = (i+=1)
              hsh
            end
          end
          
          unless column_names.include?(options[:column].to_s)
            logger.fatal("You need to create a database column '%s' in table '%s' in order to use moderation." % 
                         [@@moderation_options[:column], table_name])
            return
          end
          
          self.include(Moderateable::InstanceMethods)
          
          @@moderation_options[:flags].each_pair do |flag, value|
            named_scope("flagged_#{flag}".to_sym, :conditions => { @@moderation_options[:column] => value })
          end
        end
      end
      
      module InstanceMethods
        def moderation_flag=(flag)
          write_attribute(@@moderation_options[:column], FLAGS[flag])
        end
        
        def moderation_flag
          read_attribute(@@moderation_options[:column])
        end
        
        def flagged_as?(flag)
          @@moderation_options[:flags][flag] == self.moderation_flag
        end
      end
    end
  end
end

ActiveRecord::Base.extend(Crabgrass::Acts::Moderateable::ClassMethods)
