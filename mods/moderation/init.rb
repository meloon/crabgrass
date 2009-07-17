::YUCKY_RATING = -100

self.override_views = false
self.load_once = false

require 'acts_as_moderateable'

Dispatcher.to_prepare do
  Page.class_eval do
    
    acts_as_moderateable do 
      moderation_flag?(:public)
    end
    
    def public
      flagged_as?(:public)
    end
  end
  
  Post.class_eval do
    acts_as_moderateable :flags => [:none, :inappropriate, :vetted]
  end
  
  require 'moderation_listener'
  require 'page_view_listener'
  
  apply_mixin_to_model(Site, ModerationSiteExtension)
end
