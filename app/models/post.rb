Dir["#{RAILS_ROOT}/app/models/post/**/*.rb"].each {|x| require_dependency x}

class Post < ActiveRecord::Base
  has_many :comments, :order => "id"
  has_many :notes, :order => "id desc"
  has_many :tag_history, :class_name => "PostTagHistory", :table_name => "post_tag_histories", :order => "id desc"
  has_one :flag_detail, :class_name => "FlaggedPostDetail"
  belongs_to :user
  
  extend PostMethods::SqlMethods
  include PostMethods::CommentMethods
  extend PostMethods::ImageStoreMethods
  include PostMethods::VoteMethods
  include PostMethods::SampleMethods
  include PostMethods::TagMethods
  include PostMethods::CountMethods
  include PostMethods::CacheMethods if CONFIG["enable_caching"]
  include PostMethods::ParentMethods if CONFIG["enable_parent_posts"]
  include PostMethods::FileMethods

  before_destroy :update_status_on_destroy
  attr_accessor :updater_ip_addr, :updater_user_id, :old_rating

  image_store(CONFIG["image_store"])
    
  def self.destroy_with_reason(id, reason, current_user)
    post = Post.find(id)
    post.flag!(reason, current_user)
    post.reload
    post.destroy
  end
  
  def validate_content_type
    unless %w(jpg jpeg png gif swf).include?(self.file_ext.downcase)
      errors.add(:file, "is an invalid content type")
      return false
    end
  end
  
  def flag!(reason, creator_id)
    update_attributes(:status => "flagged")
    
    if flag_detail
      flag_detail.update_attributes(:reason => reason, :user_id => creator_id)
    else
      FlaggedPostDetail.create(:post_id => id, :reason => reason, :user_id => creator_id, :is_resolved => false)
    end
  end
  
  def approve!
    if flag_detail
      flag_detail.update_attributes(:is_resolved => true)
    end
    
    update_attributes(:status => "active")
  end

  def update_status_on_destroy
    update_attributes(:status => "deleted")
    
    if flag_detail
      flag_detail.update_attributes(:is_resolved => true)
    end
    
    return false
  end

  def favorited_by
    # Cache results
    if @favorited_by.nil?
      @favorited_by = User.find(:all, :joins => "JOIN favorites f ON f.user_id = users.id", :select => "users.name, users.id", :conditions => ["f.post_id = ?", self.id], :order => "lower(users.name)")
    end

    return @favorited_by
  end

  def rating=(r)
    if r == nil && !new_record?
      return
    end

    if is_rating_locked?
      return
    end

    r = r.to_s.downcase[0, 1]

    self.old_rating = rating

    if %w(q e s).include?(r)
      write_attribute(:rating, r)
    else
      write_attribute(:rating, 'q')
    end
  end


# Returns either the author's name or the default guest name.
  def author
    return User.find_name(user_id)
  end

  def self.find_by_tags(tags, options = {})
    return find_by_sql(Post.generate_sql(tags, options))
  end

  def pretty_rating
    case rating
    when "q"
      return "Questionable"

    when "e"
      return "Explicit"

    when "s"
      return "Safe"
    end
  end
  
  def api_attributes
    return {
      :id => id, 
      :tags => cached_tags, 
      :created_at => created_at, 
      :creator_id => user_id, 
      :source => source, 
      :score => score, 
      :md5 => md5, 
      :file_url => file_url, 
      :preview_url => preview_url, 
      :preview_width => preview_dimensions()[0],
      :preview_height => preview_dimensions()[1],
      :sample_url => sample_url,
      :sample_width => sample_width || width,
      :sample_height => sample_height || height,
      :rating => rating, 
      :has_children => has_children, 
      :parent_id => parent_id, 
      :status => status,
      :width => width,
      :height => height
    }
  end

  def to_json(options = {})
    return api_attributes.to_json(options)
  end

  def to_xml(options = {})
    return api_attributes.to_xml(options.merge(:root => "post"))
  end
  
  def delete_from_database
    connection.execute("delete from posts where id = #{self.id}")
  end
  
  def active_notes
    notes.select {|x| x.is_active?}
  end
  
  def is_flagged?
    status == "flagged"
  end
  
  def is_pending?
    status == "pending"
  end
  
  def is_deleted?
    status == "deleted"
  end
  
  def is_active?
    status == "active"
  end
  
  def can_view?(user)
    return CONFIG["can_see_post"].call(user, self)
  end
  
  def can_be_seen_by?(user)
    return can_view?(user)
  end
end
