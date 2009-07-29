module AuthenticatedSystem

  # Accesses the current user from the session.
  def current_user
    @current_user ||= begin
      user = load_user(session[:user]) if session[:user]
      user ||= UnauthenticatedUser.new
      User.current = user if user.is_a?(User) # why not UnauthenticatedUser?
      user
    end
  end

  def load_user(id)
    update_last_seen_at(id)
    user = User.find_by_id(id)
    user.current_site = current_site if user
    return user
  end

  # Returns true or false if the user is logged in.
  # Preloads @current_user with the user model if they're logged in.
  def logged_in?
    current_user.is_a?(UserExtension::AuthenticatedUser)
  end

  def logged_in_since
    session[:logged_in_since]
  end

  protected

    def update_last_seen_at(user_id)
      # we are caching these and only writing every other minute.
      Tracking.saw_user(user_id)
      #User.update_all ['last_seen_at = ?', Time.now], ['id = ?', user_id]
      #current_user.last_seen_at = Time.now
    end

    # Store the given user in the session.
    def current_user=(new_user)
      session[:user] = (new_user.nil? || new_user.is_a?(Symbol)) ? nil : new_user.id
      session[:logged_in_since] = Time.now
      @current_user = new_user
    end

    # Check if the user is authorized.
    #
    # Override this method in your controllers if you want to restrict access
    # to only a few actions or if you want to check if the user
    # has the correct rights.
    #
    # Example:
    #
    #  # only allow nonbobs
    #  def authorize?
    #    current_user.login != "bob"
    #  end
    def authorized?
      true
    end

    # Filter method to enforce a login requirement.
    #
    # To require logins for all actions, use this in your controllers:
    #
    #   before_filter :login_required
    #
    # To require logins for specific actions, use this in your controllers:
    #
    #   before_filter :login_required, :only => [ :edit, :update ]
    #
    # To skip this in a subclassed controller:
    #
    #   skip_before_filter :login_required
    #
    def login_required
      username, passwd = get_auth_data
      self.current_user ||= User.authenticate(username, passwd) || UnauthenticatedUser.new if username && passwd
      User.current = current_user
      logged_in? && authorized? ? true : access_denied
    rescue ErrorMessage => exc
      render_error(exc)
    end

    # Redirect as appropriate when an access request fails.
    #
    # The default action is to redirect to the login screen.
    #
    # Override this method in your controllers if you want to have special
    # behavior in case the user is not authorized
    # to access the requested action.  For example, a popup window might
    # simply close itself.
    def access_denied
      respond_to do |format|
        # rails defaults to first format if params[:format] is not set
        format.html do
          flash_auth_error(:later)
          redirect_to :controller => '/account', :action => 'login',
            :redirect => request.request_uri
        end
        format.js do
          flash_auth_error(:now)
          render :update do |page|
            page.replace_html 'message', display_messages
            page << 'window.location.hash = "message"'
          end
        end
        format.xml do
          headers["Status"]           = "Unauthorized"
          headers["WWW-Authenticate"] = %(Basic realm="Web Password")
          render :text => "Could not authenticate you", :status => '401 Unauthorized'
        end
      end

      false
    end

    # Store the URI of the current request in the session.
    #
    # We can return to this location by calling #redirect_back_or_default.
    def store_location
      session[:return_to] = (request.request_uri unless request.xhr?)
    end

    # Redirect to the URI stored by the most recent store_location call or
    # to the passed default.
    def redirect_back_or_default(default)
      session[:return_to] ? redirect_to_url(session[:return_to]) : redirect_to(default)
      session[:return_to] = nil
    end

    # Inclusion hook to make #current_user and #logged_in?
    # available as ActionView helper methods.
    def self.included(base)
      base.send :helper_method, :current_user, :logged_in?
    end

    # When called with before_filter :login_from_cookie will check for an :auth_token
    # cookie and log the user back in if apropriate
    def login_from_cookie
      return unless cookies[:auth_token] && !logged_in?
      user = User.find_by_remember_token(cookies[:auth_token])
      if user && user.remember_token?
        user.remember_me
        self.current_user = user
        cookies[:auth_token] = { :value => self.current_user.remember_token , :expires => self.current_user.remember_token_expires_at }
        flash[:notice] = "Logged in successfully"
      end
    end

  private

  @@http_auth_headers = %w(X-HTTP_AUTHORIZATION HTTP_AUTHORIZATION Authorization)
  # gets BASIC auth info
  def get_auth_data
    auth_key  = @@http_auth_headers.detect { |h| request.env.has_key?(h) }
    auth_data = request.env[auth_key].to_s.split unless auth_key.blank?
    return auth_data && auth_data[0] == 'Basic' ? Base64.decode64(auth_data[1]).split(':')[0..1] : [nil, nil]
  end


  def flash_auth_error(mode)
    if mode == :now
      flsh = flash.now
    else
      flsh = flash
    end

    if logged_in?
      add_flash_message(flsh, :title => "Permission Denied"[:alert_permission_denied], :error => 'You do not have sufficient permission to perform that action.'[:permission_denied_description])
    else
      add_flash_message(flsh, :title => 'Login Required'[:login_required], :success => 'Please login to perform that action.'[:login_required_description])
    end
  end

end
