class DashboardController < ApplicationController

  before_filter :authenticate_user!
  before_filter :set_user
  
  def index
    @user = current_or_guest_user
    redirect_to :action => 'news'
  end

  def venues
    @venues = Venue.of_user(@user)
    respond_to do |format|
      format.html
      format.json { render json: @venues }
    end
  end
  
  def settings
    @account = @user.account
  end
  
  def edit_settings
    @account = @user.account
  end
  
  def edit_password
    @user
  end
  
  private

  def set_user
    @user = current_or_guest_user
  end

end
