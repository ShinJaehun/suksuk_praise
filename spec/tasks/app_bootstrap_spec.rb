require "rails_helper"
require "rake"

RSpec.describe "app:bootstrap" do
  around do |example|
    original_application = Rake.application
    original_stdin = $stdin
    Rake.application = Rake::Application.new
    Rake::Task.define_task(:environment)
    load Rails.root.join("lib/tasks/app_bootstrap.rake")
    example.run
  ensure
    $stdin = original_stdin
    Rake.application = original_application
  end

  it "exits successfully without prompting when an administrator exists" do
    create(:user, :admin)

    expect {
      Rake::Task["app:bootstrap"].invoke
    }.to output(
      "An administrator account already exists.\nBootstrap was not run.\n"
    ).to_stdout
  end

  it "exits with a non-zero status for blank input" do
    $stdin = StringIO.new("\n")

    expect {
      Rake::Task["app:bootstrap"].invoke
    }.to raise_error(SystemExit) { |error| expect(error.status).to eq(1) }
  end
end
