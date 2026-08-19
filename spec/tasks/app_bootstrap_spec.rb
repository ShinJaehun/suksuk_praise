require 'rails_helper'
require 'rake'

RSpec.describe 'app:bootstrap' do
  around do |example|
    original_application = Rake.application
    original_stdin = $stdin
    original_stdout = $stdout
    original_stderr = $stderr
    Rake.application = Rake::Application.new
    Rake::Task.define_task(:environment)
    load Rails.root.join('lib/tasks/app_bootstrap.rake')
    example.run
  ensure
    $stdin = original_stdin
    $stdout = original_stdout
    $stderr = original_stderr
    Rake.application = original_application
  end

  it 'exits successfully without prompting when an administrator exists' do
    create(:user, :admin)

    expect do
      Rake::Task['app:bootstrap'].invoke
    end.to output(
      "An administrator account already exists.\nBootstrap was not run.\n"
    ).to_stdout
  end

  it 'exits with a non-zero status for blank input' do
    $stdin = StringIO.new("\n")
    $stdout = StringIO.new
    $stderr = StringIO.new
    expect do
      Rake::Task['app:bootstrap'].invoke
    end.to raise_error(SystemExit) { |error| expect(error.status).to eq(1) }

    expect($stdout.string).to eq('Administrator name: ')
    expect($stderr.string).to eq("Administrator name cannot be blank.\n")
  end
end
