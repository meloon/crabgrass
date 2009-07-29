module PageExtension::Create
  def self.included(base)
    base.extend(ClassMethods)
    #base.instance_eval do
    #  include InstanceMethods
    #end
  end

  #
  # special magic page create
  #
  # just like a normal activerecord.create, but with some magic options that
  # may optionally be passed in as attributes:
  #
  #  :user -- the user creating the page. they become the creator and owner
  #           of the page.
  #  :share_with -- other people, groups, or emails to share this page with.
  #  :access -- what access to grant them (defaults to :admin)
  #  :inbox -- send page to inbox?
  #
  # if anything goes wrong, an exception is raised, so watch out.
  # see UserExtension::Sharing#may_share_page_with!
  #
  # There are two versions create!() and create(). Both might throw exceptions
  # caused by bad sharing, but the first one will also throw exceptions if the
  # attributes don't validate.
  #
  module ClassMethods
    def create!(attributes = {}, &block)
      page = build!(attributes, &block)
      page.save!
      page
    end

    def create(attributes={}, &block)
      begin
        create!(attributes, &block)
      rescue ActiveRecord::RecordInvalid => exc
        exc.record
      end
    end

    #
    # build a page in memory, but don't save anything.
    #
    def build!(attributes={}, &block)
      if attributes.is_a?(Array)
        # act like normal create
        super(attributes, &block)
      else
        # extract extra attributes
        attributes = attributes.dup
        user       = attributes.delete(:user)
        owner      = attributes.delete(:owner)
        recipients = attributes.delete(:share_with)
        inbox      = attributes.delete(:inbox)
        access     = (attributes.delete(:access) || :admin).to_sym
        attributes[:created_by] ||= user
        attributes[:updated_by] ||= user

        Page.transaction do
          page = new(attributes)
          page.owner = owner if owner
          yield(page) if block_given?
          if user
            if recipients
              user.share_page_with!(page, recipients, :access => access,
                                    :send_notice => inbox)
            end
            unless user.may_admin?(page)
              page.user_participations.build(:user_id => user.id, :access => ACCESS[:admin], :inbox => inbox)
            end
          end
          page
        end
      end
    end

    # parses a list of recipients, turning them into email, user, or group
    # objects as appropriate.
    # returns array [users, groups, emails]
    def parse_recipients!(recipients)
       users = []; groups = []; emails = []; errors = []
      if recipients.is_a? Hash
        entities = []
        recipients.each do |key,value|
          entities << key if value.is_a?(Hash)
        end
      elsif recipients.is_a? Array
        entities = recipients
      elsif recipients.is_a? String
        entities = recipients.split(/[\s,]/)
      else
        entities = [recipients]
      end

      entities.each do |entity|
        if entity.is_a? Group
          groups << entity
        elsif entity.is_a? User
          users << entity
        elsif u = User.find_by_login(entity.to_s)
          users << u
        elsif g = Group.find_by_name(entity.to_s)
          groups << g
        elsif entity =~ RFC822::EmailAddress
          emails << entity
        elsif entity.any?
          errors << '"%s" does not match the name of any users or groups and is not a valid email address'[:name_or_email_not_found] % entity
        end
      end

      unless errors.empty?
        raise ErrorMessages.new('Could not understand some recipients.', errors)
      end

      [users, groups, emails]
    end # parse_recipients!

  end # ClassMethods
end # PageExtension::Create


