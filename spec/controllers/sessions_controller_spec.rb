require 'rails_helper'

describe Users::SessionsController do

  before do
    @user =  FactoryGirl.create(:user, {password: '123123', password_confirmation: '123123'})
    @request.env["devise.mapping"] = Devise.mappings[:user]
  end

  describe "Sign In" do

    describe 'successful' do
      before do
        allow(request.env['warden']).to receive_messages :authenticate! => @user
        allow(controller).to receive_messages :current_user => @user
      end

      it "via form" do
        post :create, { email: @user.email, password: '123123'}
        expect(response.status).to be(302)
      end

      it "via json with authentication_token" do
        post :create, { email: @user.email, password: '123123', format: 'json' }
        res = JSON.parse(response.body)
        expect(res).to_not be_empty
        expect(res['authentication_token']).to_not be_empty
      end
    end

    describe 'failure' do
      it "via form" do
        post :create, { email: @user.email, password: 'wrong_pwd'}
        expect(response.status).to be(200)
      end

      it "via json" do
        post :create, { email: @user.email, password: 'wrong_pwd', format: 'json' }
        res = JSON.parse(response.body)
        expect(res).to_not be_empty
        expect(res['error']).to_not be_empty
        expect(response.status).to be(401)
      end
    end
  end

end
