::YUCKY_RATING = -100

self.override_views = false
self.load_once = false

require 'acts_as_moderateable'

Dispatcher.to_prepare do
  Page.class_eval do
    acts_as_moderateable :approve => [:public], :flags => { 
      :inappropriate => { 
        :delete => lambda { |page| page.update_attribute(:flow, FLOW[:deleted]) }
      }
    }
  end
  
  Post.class_eval do
    acts_as_moderateable :flags => { 
      :inappropriate => { 
        :delete => lambda { |post| post.update_attribute(:deleted_at, Time.now) }
      }
    }
  end
  
  require 'moderation_listener'
  require 'page_view_listener'
  
  apply_mixin_to_model(Site, ModerationSiteExtension)
end
