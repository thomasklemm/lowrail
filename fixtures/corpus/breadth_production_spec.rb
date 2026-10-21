# frozen_string_literal: true

# A bounded production probe, not the apps' test suites (which require test
# mode). Run from the unchanged app with rspec --options /dev/null this_file.
require File.expand_path("config/environment", Dir.pwd)

RSpec.describe "gem-breadth production boundary" do
  it "boots in the requested production/YJIT mode and executes own-thread SQL" do
    expect(Rails.env.production?).to eq(true)
    expect(RubyVM::YJIT.enabled?).to eq(true)
    expect(ActiveRecord::Base.connection.select_value("SELECT 19 + 23")).to eq(42)
  end

  case ENV.fetch("LOWRAIL_COMPAT_APP")
  when "rubytoolbox"
    it "uses the app's dry struct coercions and class-body Sidekiq options" do
      info = Rubygem::Advisory::Info.new(
        id: "LR-42", url: nil, date: "2026-10-21", cve: nil, ghsa: nil,
        osvdb: 37, cvss_v2: "3.2", cvss_v3: nil, criticality: "moderate",
        title: "Probe", description: nil, unaffected_versions: [],
        patched_versions: [{"requirements" => [[">=", {"version" => "1.2.3"}]]}]
      )
      expect(info.identifier).to eq("LR-42")
      expect(info.osvdb).to eq("37")
      expect(info.cvss_v2).to eq(3.2)
      expect(info.date).to eq(Date.new(2026, 10, 21))
      expect(info.patched_versions).to eq([[">= 1.2.3"]])
      expect { Rubygem::Advisory::Info.new(id: 42) }.to raise_error(Dry::Struct::Error)
      expect(RubygemUpdateJob.get_sidekiq_options.fetch("retry")).to eq(3)
      expect(RubygemUpdateJob.get_sidekiq_options.fetch("lock")).to eq(:until_executing)
      record = Rubygem.find_by_sql("SELECT 'lowrail-boundary' AS name").fetch(0)
      expect([record.name, record.new_record?]).to eq(["lowrail-boundary", false])
    end
  when "fat-free-crm"
    it "retains PaperTrail model registration and Ransack's real app scope" do
      expect(Lead.paper_trail.version_class).to eq(Version)
      expect(PaperTrail.enabled?).to eq(true)
      query = Lead.text_search("LowrailBoundary").to_sql
      expect(query).to include("LowrailBoundary", "first_name", "last_name", "company", "email")
      record = Lead.find_by_sql("SELECT 193 AS id, 'Exact' AS first_name, 'Boundary' AS last_name, NULL AS user_id").fetch(0)
      expect([record.id, record.first_name, record.last_name, record.new_record?]).to eq([193, "Exact", "Boundary", false])
      ActiveRecord::Associations::Preloader.new(records: [record], associations: :user).call
      expect(record.user).to eq(nil)
      campaign = Campaign.find_by_sql("SELECT -193 AS id, 'Probe' AS name").fetch(0)
      3.times { expect(campaign.leads.reload.to_a).to eq([]) }
    end
  when "wikino"
    it "renders an app ViewComponent through Sorbet-wrapped definitions" do
      component = BaseUI::ContainerComponent
      instance = component.new(as: component::As::Section,
        content_screen: component::ContentScreen::Large, options: {class: "probe"})
      output = instance.render_in(ApplicationController.new.view_context) { "Typed content" }
      expect(output).to include("<section", "probe", "content-screen-max-width-large", "Typed content")
      expect { component.new(as: "section") }.to raise_error(TypeError)
      record = UserRecord.find_by_sql("SELECT '00000000-0000-4000-8000-000000000193'::uuid AS id, 'lowrail-boundary' AS atname, 'Typed' AS name, 0 AS locale").fetch(0)
      expect([record.atname, record.name, record.locale, record.new_record?]).to eq(["lowrail-boundary", "Typed", "en", false])
      ActiveRecord::Associations::Preloader.new(records: [record], associations: :space_member_records).call
      expect(record.space_member_records.to_a).to eq([])
    end
  else
    raise "unknown LOWRAIL_COMPAT_APP"
  end
end
