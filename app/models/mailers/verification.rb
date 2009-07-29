module Mailers::Verification

  # Send an email letting the user know that a page has been 'sent' to them.
  def email_verification(token, options)
    setup(options)

    recipients @current_user.email
    subject 'Welcome to {site_title}!'[:welcome_to_site_tile, {:site_title => @site.title}]
    body({:site_title => @site.title,
            :link => account_verify_url(:token => token.value),
            :host => @host})
  end

end

