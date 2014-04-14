class LandingPageController < ApplicationController

  def index
    @talks_featured = Talk.featured.limit(5)
    @talks_live     = Talk.live.limit(5)
    @talks_archived = Talk.archived.order('ended_at DESC').limit(5)
    @talks_popular  = Talk.archived.order('play_count DESC').limit(5)
    @user           = User.new
  end

end
