require 'spec_helper'

describe "Participations" do
  describe "create and destroy" do
    before do
      @talk = FactoryGirl.create(:talk)
      @user = FactoryGirl.create(:user)
      login_user @user
    end
    it "creates a participation from Talk" do
      expect {
        visit talk_path(@talk)
        click_on "Participate"
      }.to change(Participation, :count).by(1)
    end
    it "redirects to Talk" do
      visit talk_path(@talk)
      click_on "Participate"
      current_path.should == venue_talk_path(@talk.venue, @talk)
    end
    it "creates a participation from Series" do
      expect {
        visit venue_path(@talk.venue)
        click_on "SUBSCRIBE TO Series!"
      }.to change(Participation, :count).by(1)
    end
    it "deletes a participation from Series" do
      FactoryGirl.create(:participation, venue: @talk.venue, user: @user)
      expect {
        visit venue_path(@talk.venue)
        click_on "Leave Venue"
      }.to change(Participation, :count).by(-1)
      current_path.should == venue_path(@talk.venue)
    end
  end
end
