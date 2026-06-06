FactoryBot.define do
  factory :captain_media_asset, class: 'Captain::MediaAsset' do
    association :account
    association :assistant, factory: :captain_assistant, account: account
    sequence(:name) { |n| "Product image #{n}" }
    currency { 'EUR' }
    price_cents { 89_000 }
    description { 'Sample catalog item' }
    tags { %w[gold ring] }
    active { true }

    after(:build) do |media_asset|
      next if media_asset.image.attached?

      media_asset.image.attach(
        io: Rails.root.join('public/assets/images/dashboard/captain/logo.svg').open,
        filename: 'product.png',
        content_type: 'image/svg+xml'
      )
    end
  end
end
