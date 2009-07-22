module Crabgrass
  module Acts
    module Moderateable
      MOD_FLAG_STATES = { :flagged => 1, :vetted => 2 }
      module ClassMethods
        def acts_as_moderateable(options={})
          options = { 
            :approve => [],       # columns that require a moderator's approval before they actually happen
            :flags => {},         # flags that require the attention of a moderator (e.g. inappropriate) with actions that
                                  # the moderator can perform
          }.merge(options)
          [options[:approve]].flatten.each do |column|
            # e.g. public= will set `public_requested'
            define_method("#{column}=".intern) do |value|
              write_attribute("#{column}_requested", value)
            end
            
            # e.g. approve_public will set `public' to the value of `public_requested'
            define_method("approve_#{column}".intern) do 
              value = read_attribute("#{column}_requested")
              write_attribute("#{column}_requested", nil)
              write_attribute(column, value)
            end
            # e.g. decline_public will unset `public_requested'
            define_method("decline_#{column}".intern) do 
              write_attribute("#{column}_requested", nil)
            end
            
            named_scope("requested_#{column}".intern, { :conditions => ["#{column}_requested IS ?", true] })
          end
          options[:flags].each_pair do |column, actions|
            # e.g. flag_inappropriate will set `inappropriate' to 1
            define_method("flag_#{column}".intern) do 
              write_attribute(column, MOD_FLAG_STATES[:flagged])
            end
            # e.g. vet_inappropriate(:delete) will call the :delete block and pass in the object
            #      vet_inappropriate without any options will just set the vetted flag.
            define_method("vet_#{column}".intern) do |action|
              if action
                raise ArgumentError.new("No such vetting action: %s. Available actions are %s"%
                                        [action, actions.keys.join(', ')]) unless actions.keys.include?(action)
                actions[action].call(self)
              end
              write_attribute(column, MOD_FLAG_STATES[:vetted])
            end
            
            named_scope("flagged_#{column}".intern, { :conditions => ["#{column} IS ?", MOD_FLAG_STATES[:flagged]]})
            named_scope("vetted_#{column}".intern, { :conditions => ["#{column} IS ?", MOD_FLAG_STATES[:vetted]]})
          end
        end
      end
    end
  end
end

ActiveRecord::Base.extend(Crabgrass::Acts::Moderateable::ClassMethods)
