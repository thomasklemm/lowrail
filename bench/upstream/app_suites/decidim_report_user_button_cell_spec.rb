# frozen_string_literal: true

# Scratch spec (Lowrail Decidim round): renders the report-user modal, a cell with a POST form.
require "spec_helper"

describe Decidim::ReportUserButtonCell, type: :cell do
  controller Decidim::PagesController

  let(:organization) { create(:organization) }
  let(:user) { create(:user, :confirmed, organization:) }
  let(:current_user) { create(:user, :confirmed, organization:) }

  before do
    allow(controller).to receive(:current_user).and_return(current_user)
    allow(controller).to receive(:current_organization).and_return(organization)
  end

  it "renders the report form" do
    html = cell("decidim/report_user_button", user, button_classes: "button").call
    expect(html.to_s).to include("<form")
  end
end
