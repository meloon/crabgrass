class Gallery < Page

  has_many :showings, :order => 'position', :dependent => :destroy
  has_many :images, :through => :showings, :source => :asset, :order => 'showings.position'

  def supports_attachments
    false
  end
  
  def add_image!(asset, user=nil, position = nil)
    check_for_page(asset, user)
    check_permissions!(asset, user)
    check_type!(asset)
    Showing.create! :gallery => self, :asset => asset, :position => position
    reset_associations(asset)
    if user
      user.updated(self)
    end
    true
  end
  
  def cover
    self.cover_showing ? self.cover_showing.asset : nil
  end
  
  def cover_showing
    self.showings.find_by_is_cover(true) ||
      self.showings.find_by_position(0) ||
      self.showings.first
  end
  
  def cover=(image_id)
    showing = self.showings.find_by_asset_id(image_id)
    raise ArgumentError unless showing
    old = self.cover_showing
    old.is_cover = false
    old.save
    showing.is_cover = true
    showing.save
  end

  
  # like add_image!, but does not save the page. Used to build
  # the associations in memory when creating a new page.
  #def add_image(asset, position = nil)
  #  asset.showings.build(:gallery => self, :position => position)
  #end

  def remove_image!(asset)
    showing = self.showings.detect{|showing| showing.asset_id == asset.id}
    reset_associations(asset)
    showing.destroy
  end

  private
  
  def reset_associations(asset)
    #asset.showings.reset
    #asset.galleries.reset
    #self.showings.reset
    #self.images.reset
  end

  def check_permissions!(asset, user)
    unless user.may?(:view,asset.page)
      raise PermissionDenied.new('The group that owns this page is not allowed to view that image'[:group_not_allowed_to_view_image_error])
    end
  end

  def check_type!(asset)
    raise ErrorMessage.new('File must be an image to be part of a gallery'[:file_must_be_image_error]) unless asset.is_image?
  end
  
  def check_for_page(asset, user)
    unless asset.page
      up=0
      gp=0
      page = asset.pages.create!(:title => asset.filename, :data_id => asset.id,
                                 :flow => FLOW[:gallery])
      self.group_participations.each do |gpart|
        page.group_participations.create(:group_id => gpart.group_id,
                                         :access => gpart.access)
        gp+=1
      end
      self.user_participations.each do |upart|
        page.user_participations.create(:user_id => upart.user_id,
                                        :access => upart.access)
        up+=1
      end
      page.save
      if user
        user.updated(page)
        page.save
      end
    end
  end

end
