
$: << "#{RAILS_ROOT}/lib/rubyvote/lib"
require 'election'
require 'positional'

# add rank calculation functions to BordaResult class
# should this go in its own function?
class BordaResult

  def rank(possible)
    @ranks ||= calculate_ranks
    return @ranks[possible]
  end

  private

  def calculate_ranks
  ranks = {}
    rank = 0
    previous_points = -1
    ranked_candidates.each do |candidate|
      rank += 1 if points[candidate] != previous_points
      ranks[candidate] = rank
      previous_points = points[candidate]
    end
    return ranks
  end

end

class RankedVotePageController < BasePageController
  before_filter :fetch_poll
  before_filter :find_possibles, :only => [:show, :edit]
  stylesheet 'vote'
  permissions 'ranked_vote_page'
  javascript :extra, 'page'

  def show
    redirect_to(page_url(@page, :action => 'edit')) unless @poll.possibles.any?

    array_of_votes, @who_voted_for = build_vote_arrays
    @result = BordaVote.new( array_of_votes ).result
    @sorted_possibles = @result.ranked_candidates.collect { |id| @poll.possibles.find(id)}
  end

  def edit
  end

  # ajax or post
  def add_possible
    return if request.get?
    @possible = @poll.possibles.create params[:possible]
    if @poll.valid? and @possible.valid?
      @page.unresolve
      redirect_to page_url(@page) unless request.xhr?
      render :template => 'ranked_vote_page/add_possible'
    else
      @poll.possibles.delete(@possible)
      flash_message_now :object => @possible unless @possible.valid?
      flash_message_now :object => @poll unless @poll.valid?
      if request.post?
        render :action => 'show'
      else
        render :text => 'error', :status => 500
      end
      return
    end
  end

  # ajax only, returns nothing
  # for this to work, there must be a <ul id='sort_list_xxx'> element
  # and it must be declared sortable like this:
  # <%= sortable_element 'sort_list_xxx', .... %>
  def sort
    if params[:sort_list_voted].empty?
      render :nothing => true
      return
    else
      @poll.delete_votes_by_user(current_user)
      ids = params[:sort_list_voted]
      ids.each_with_index do |id, rank|
        next unless id.to_i != 0
        possible = @poll.possibles.find(id)
        possible.votes.create :user => current_user, :value => rank
      end
      find_possibles
    end
  end

  def update_possible
    return unless request.xhr?
    @possible = @poll.possibles.find(params[:id])
    params[:possible].delete('name')
    @possible.update_attributes(params[:possible])
    render :template => 'ranked_vote_page/update_possible'
  end

  def edit_possible
    return unless request.xhr?
    @possible = @poll.possibles.find(params[:id])
    render :template => 'ranked_vote_page/edit_possible'
  end

  def destroy_possible
    possible = @poll.possibles.find(params[:id])
    possible.destroy
    render :nothing => true
  end

  def confirm
    # right now, this is just an illusion, but perhaps we should make the vote
    # only get saved after confirmation. people like the confirmation, rather
    # then the weird ajax-only sorting.
    redirect_to page_url(@page)
  end

  def print
    array_of_votes, @who_voted_for = build_vote_arrays
    @result = BordaVote.new( array_of_votes ).result
    @sorted_possibles = @result.ranked_candidates.collect { |id| @poll.possibles.find(id)}

    render :layout => "printer-friendly"
  end
  protected

  # returns:
  # 1) an array suitable for RubyVote
  # 2) a hash mapping possible name to an array of users who picked ranked this highest

  def build_vote_arrays
    who_voted_for = {}  # what users picked this possible as their first
    hash = {}           # tmp hash
    array_of_votes = [] # returned array for rubyvote

    ## first, build hash of votes
    ## the key is the user's id and the element is an array of all their votes
    ## where each vote is [possible_name, vote_value].
    ## eg. { 5 => [["A",0],["B",1]], 22 => [["A",1],["B",0]]
    possibles = @poll.possibles.find(:all, :include => {:votes => :user})
    # (perhaps this should be changed if we start caching User.find(id)
    #possibles = @poll.possibles.find(:all, :include => :votes)

    possibles.each do |possible|
      possible.votes.each do |vote|
        hash[vote.user.name] ||= []
        hash[vote.user.name] << [possible.id, vote.value]
      end
    end

    ## second, build array_of_votes.
    ## each element is an array of a user's
    ## votes, sorted in order of their preference
    ## eg. [ ["A", "B"],  ["B", "A"], ["B", "A"] ]
    hash.each_pair do |user_id, votes|
      sorted_by_value = votes.sort_by{|vote|vote[1]}
      top_choice_name = sorted_by_value.first[0]
      array_of_votes << sorted_by_value.collect{|vote|vote[0]}
      who_voted_for[top_choice_name] ||= []
      who_voted_for[top_choice_name] << user_id
    end

    return array_of_votes, who_voted_for
  end


  def fetch_poll
    @poll = @page.data if @page
    true
  end

  def find_possibles
    @possibles_voted = []
    @possibles_unvoted = []

    @poll.possibles.each do |pos|
      if pos.vote_by_user(current_user)
        @possibles_voted << pos
      else
        @possibles_unvoted << pos
      end
    end

    @possibles_voted = @possibles_voted.sort_by { |pos| pos.value_by_user(current_user) }
  end

  def setup_view
    @show_print = true
  end

  def build_page_data
    Poll.new
  end
end

