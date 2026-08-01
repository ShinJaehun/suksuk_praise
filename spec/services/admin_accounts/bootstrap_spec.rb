require 'rails_helper'

RSpec.describe AdminAccounts::Bootstrap, type: :service do
  let(:attributes) do
    {
      name: 'Initial Administrator',
      email: 'initial-admin@example.com',
      password: 'secure-password'
    }
  end

  it 'creates the initial administrator with the required attributes' do
    admin = described_class.call!(**attributes)

    expect(admin).to have_attributes(
      name: 'Initial Administrator',
      email: 'initial-admin@example.com',
      role: 'admin',
      active: true,
      avatar_key: 'admin'
    )
    expect(admin.valid_password?('secure-password')).to eq(true)
  end

  it 'creates four default library coupons with the administrator' do
    admin = described_class.call!(**attributes)

    expect(CouponTemplate.where(created_by: admin, bucket: 'library').count).to eq(4)
  end

  it 'refuses to create another administrator when one already exists' do
    existing_admin = create(:user, :admin)

    expect do
      described_class.call!(**attributes)
    end.to raise_error(described_class::AdministratorAlreadyExistsError)

    expect(User.admin).to contain_exactly(existing_admin)
  end

  it 'rolls back the administrator when default coupon creation fails' do
    allow(CouponTemplates::DefaultLibrarySeeder)
      .to receive(:call!)
      .and_raise(ActiveRecord::RecordInvalid)

    expect do
      described_class.call!(**attributes)
    end.to raise_error(described_class::CouponLibraryCreationError)

    expect(User.admin).to be_empty
    expect(CouponTemplate.count).to eq(0)
  end
end
