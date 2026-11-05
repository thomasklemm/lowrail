# frozen_string_literal: true

# Scratch spec (Lowrail Decidim round): a visitor opens another user's profile page.
require "spec_helper"

RSpec.describe "Profile page", type: :request do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, :confirmed, organization:) }

  it "renders" do
    get("/profiles/#{user.nickname}", headers: { "HOST" => organization.host })
    follow_redirect! while response.redirect?
    expect(response).to have_http_status(:ok)
  end
end
