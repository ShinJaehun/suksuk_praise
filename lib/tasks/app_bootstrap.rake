# frozen_string_literal: true

require "io/console"

namespace :app do
  desc "Create the initial administrator account and default coupon library"
  task bootstrap: :environment do
    if User.admin.exists?
      puts "An administrator account already exists."
      puts "Bootstrap was not run."
      next
    end

    read_input = lambda do |prompt, hidden: false|
      print "#{prompt} "
      input = if hidden
        $stdin.noecho(&:gets).tap { puts }
      else
        $stdin.gets
      end

      raise EOFError if input.nil?

      input.chomp
    end

    name = read_input.call("Administrator name:")
    raise ArgumentError, "Administrator name cannot be blank." if name.blank?

    email = read_input.call("Administrator email:")
    raise ArgumentError, "Administrator email cannot be blank." if email.blank?

    password = read_input.call("Administrator password:", hidden: true)
    raise ArgumentError, "Administrator password cannot be blank." if password.blank?

    password_confirmation = read_input.call("Confirm administrator password:", hidden: true)
    unless password == password_confirmation
      raise ArgumentError, "Administrator password confirmation does not match."
    end

    AdminAccounts::Bootstrap.call!(name: name, email: email, password: password)

    puts "Initial administrator account created."
    puts "Default coupon library created with 4 coupons."
  rescue EOFError
    warn "Input ended before bootstrap was complete."
    exit 1
  rescue ArgumentError => error
    warn error.message
    exit 1
  rescue AdminAccounts::Bootstrap::AdministratorAlreadyExistsError
    puts "An administrator account already exists."
    puts "Bootstrap was not run."
  rescue ActiveRecord::RecordInvalid => error
    warn "Administrator account could not be created: #{error.record.errors.full_messages.to_sentence}"
    exit 1
  rescue AdminAccounts::Bootstrap::CouponLibraryCreationError
    warn "Default coupon library could not be created."
    exit 1
  rescue StandardError
    warn "Bootstrap failed."
    exit 1
  end
end
