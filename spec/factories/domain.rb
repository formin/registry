FactoryBot.define do
  factory :domain do
    sequence(:name) { |n| "test#{n}.com" }
    period 1
    period_unit 'y' # Year
    registrar
    registrant

    after :build do |domain|
      domain.admin_domain_contacts << FactoryBot.build(:admin_domain_contact)
      domain.tech_domain_contacts << FactoryBot.build(:tech_domain_contact)
    end
  end
end
