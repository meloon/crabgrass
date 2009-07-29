require File.dirname(__FILE__) + '/../test_helper'

class ToolTest < Test::Unit::TestCase

  def setup
  end

  def test_tool_namespace
    new = MessagePage.new :title => 'a message', :public => true
    assert new.save!

    find_base = Page.find(new)
    assert_equal find_base.send(:read_attribute, :type), 'MessagePage'
    assert find_base.is_a?(MessagePage)

    assert_nothing_raised do
      find = Page.find(new.id)
    end
  end

end
