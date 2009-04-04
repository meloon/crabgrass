PageClassRegistrar.add(
  'SurveyPage',
  :controller => 'survey_page',
  :icon => 'page_tasks',
  :class_display_name => 'survey',
  :class_description => :survey_class_description,
  :class_group => 'survey',
  :order => 4
)

require File.join(File.dirname(__FILE__), 'lib',
                  'survey_user_extension')

apply_mixin_to_model(SurveyUserExtension, "User")

#self.override_views = true
self.load_once = false
