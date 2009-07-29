class Admin::PostsController < Admin::BaseController
  verify :method => :post, :only => [:update]

  permissions 'admin/moderation'

  def index
    view = params[:view] || 'all'
    @current_view = view
    if view == 'all'
      options = { :order => 'updated_at DESC' }
    elsif %w(new pending).include?(view)
      # all posts that have been flagged as inappropriate have not had any admin action yet.
      options = { :conditions => ['(vetted = ? AND rating = ?)', false, YUCKY_RATING], :joins => :ratings, :order => 'updated_at DESC' }
    elsif view == 'vetted'
      # all posts that have been marked as vetted by an admin (and are not deleted)
      options = { :conditions => ['vetted = ? AND deleted_at IS NULL', true], :order => 'updated_at DESC' }
    elsif view == 'deleted'
      # list the pages that are 'deleted' by being hidden from view.
      options = { :conditions => ['deleted_at IS NOT NULL'], :order => 'updated_at DESC' }
    end
    # defined by subclasses
    fetch_posts(options)
  end

  # for vetting:       params[:post][:vetted] == true
  # for hiding:        params[:post][:deleted] == true
  def update
    @posts = Post.find(params[:id])
    @posts.update_attributes(params[:post])
    redirect_to :action => 'index', :view => params[:view]
  end


  # Approves a post by marking :vetted = true
  def approve
    post = Post.find params[:id]
    post.update_attribute(:vetted, true)
    # get rid of all yucky associated with the post
    post.ratings.destroy_all

    redirect_to :action => 'index', :view => params[:view]
  end

  # Reject a post by setting deleted_at=now, the post will now be 'deleted'(hidden)
  def trash
    post = Post.find params[:id]
    post.update_attribute(:deleted_at, Time.now)
    post.discussion.page.save if post.discussion.page
    redirect_to :action => 'index', :view => params[:view]
  end

  # undelete a post by setting setting deleted_at=false, the post will now be 'undeleted'(unhidden)
  def undelete
    post = Post.find params[:id]
    post.update_attribute(:deleted_at, nil)
    post.discussion.page.save if post.discussion.page
    redirect_to :action => 'index', :view => params[:view]
  end

  def set_active_tab
    @active_tab = :moderation
  end
end

