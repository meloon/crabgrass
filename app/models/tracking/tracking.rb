# um, so, yeah, basically we don't use ActiveRecord for this.
# lots of MySQL-specific stuff here.
class Tracking < ActiveRecord::Base
  belongs_to :page
  belongs_to :group
  belongs_to :user

  @seen_users=Set.new

  # Tracks the actions quickly. Following things can be tracked:
  # :user - user that was doing anything
  # :action - one of :view, :edit, :star
  # :page - page that this happened on
  # :group - group context
  def self.insert_delayed(things={})
    return false if things.empty?
    connection.execute("INSERT DELAYED INTO #{table_name}
      (page_id, group_id, user_id, views, edits, stars, tracked_at)
      VALUES (#{values_for_tracking(things).join(', ')})")
    true
  end

  def self.saw_user(user_id)
    @seen_users << user_id
    true
  end
  ##
  ## Sets last_seen for users that were active in the last 5 minutes.
  ##
  def self.update_last_seen_users
    connection.execute("UPDATE users
                       SET users.last_seen_at = UTC_TIMESTAMP() - INTERVAL 1 MINUTE
                       WHERE users.id IN (#{@seen_users.to_a.join(', ')})")
    @seen_users.clear
    true
  end


  ##
  ## Takes all the page view records that have been inserted into trackings
  ## table and updates the view counts in the hourlies and membership tables with
  ## this data. Afterward, all the data in trackings table is deleted.
  ##

  def self.process
    return if (Tracking.count == 0)
    begin
      connection.execute("LOCK TABLES #{table_name} WRITE, hourlies WRITE, memberships WRITE, user_participations WRITE")
      unprocessed_since=Tracking.find(:first, :order => :tracked_at).tracked_at
      # ups - almost 20 lines of sql - this definitly needs a rewrite:
      # TODO: include edit counts in normal trackings to avoid the LEFT JOIN --azul
      connection.execute("INSERT INTO hourlies
                           (page_id, views, stars, edits, created_at)
                           SELECT trackings.page_id, trackings.view_count, trackings.star_count,
                                  participations.contributor_count,
                                  TIMESTAMPADD(HOUR, trackings.hour + 1, trackings.date)
                           FROM (
                             SELECT page_id, SUM(views) as view_count, SUM(stars) as star_count,
                               DATE(tracked_at) as date, HOUR(tracked_at) as hour
                             FROM #{table_name} GROUP BY page_id, date, hour
                           ) as trackings LEFT JOIN(
                             SELECT page_id, COUNT(*) as contributor_count,
                               DATE(changed_at) as date, HOUR(changed_at) as hour
                             FROM user_participations
                             WHERE (user_participations.changed_at > '#{unprocessed_since.to_s(:db)}')
                             GROUP BY page_id, date, hour
                           ) as participations
                           ON trackings.page_id = participations.page_id AND
                             trackings.date = participations.date AND
                             trackings.hour = participations.hour
                         ")

      connection.execute("CREATE TEMPORARY TABLE group_view_counts
                         SELECT COUNT(*) AS c, user_id, group_id, MAX(tracked_at) as tracked_at
                         FROM #{table_name} GROUP BY user_id, group_id")
      connection.execute("UPDATE memberships, group_view_counts
                         SET memberships.visited_at = group_view_counts.tracked_at,
                           memberships.total_visits = memberships.total_visits + group_view_counts.c
                         WHERE memberships.user_id = group_view_counts.user_id AND
                           memberships.group_id = group_view_counts.group_id")
      connection.execute("DROP TEMPORARY TABLE group_view_counts")

      self.delete_all
    ensure
      connection.execute("UNLOCK TABLES")
    end
    # do this after unlocking tables just to try to minimize the amount of time tables are locked…
    connection.execute("UPDATE page_terms,hourlies
                       SET page_terms.views_count = page_terms.views_count + hourlies.views
                       WHERE page_terms.page_id=hourlies.page_id AND hourlies.created_at > '#{unprocessed_since.to_s(:db)}' + INTERVAL 30 MINUTE")
    connection.execute("UPDATE page_terms,pages
                       SET pages.views_count = page_terms.views_count
                       WHERE pages.id=page_terms.page_id")
    true
  end

  protected

  # returns an array of (page_id, group_id, user_id, views, edits, stars, tracked_at)
  # for use in mysql values
  def self.values_for_tracking(things)
    views = things[:action] == :view ? 1 : 0
    edits = things[:action] == :edit ? 1 : 0
    stars = things[:action] == :star ? 1 : 0
    stars -= things[:action] == :unstar ? 1 : 0
    thing_ids = things.values_at(:page, :group, :user).collect{|t| quoted_id(t)}
    thing_ids.concat [views, edits, stars, "UTC_TIMESTAMP()"]
  end

  def self.quoted_id(thing)
    connection.quote(id_from(thing))
  end

  def self.id_from(thing)
    if thing
      thing.is_a?(Fixnum) ?
        thing :
        thing.id
    end
  end
end
