require "rails_helper"

RSpec.describe "Admin dashboard", type: :request do
  before { host! "localhost" }

  it "requires admin authentication for overview" do
    get admin_dashboard_path

    expect(response).to redirect_to(admin_login_path)
  end

  it "requires admin authentication for finance screen" do
    get finance_admin_dashboard_path

    expect(response).to redirect_to(admin_login_path)
  end

  it "requires admin authentication for simulator screen" do
    get simulator_admin_dashboard_path

    expect(response).to redirect_to(admin_login_path)
  end

  it "requires admin authentication for alerts screen" do
    get alerts_admin_dashboard_path

    expect(response).to redirect_to(admin_login_path)
  end
end
