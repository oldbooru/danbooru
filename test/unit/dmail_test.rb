require File.dirname(__FILE__) + '/../test_helper'

class DmailTest < ActiveSupport::TestCase
  fixtures :users
  
  def test_all
    msg = Dmail.create(:to_name => "member", :from_name => "admin", :title => "hello", :body => "hello")
    assert_equal(4, msg.to_id)
    assert_equal(1, msg.from_id)
    assert_equal(true, User.find(4).has_mail)
    
    response_a = Dmail.create(:to_name => "admin", :from_name => "member", :parent_id => msg.id, :title => "hello", :body => "you are wrong")
    assert_equal("Re: hello", response_a.title)
  end
end