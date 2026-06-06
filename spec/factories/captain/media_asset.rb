FactoryBot.define do
  factory :captain_media_asset_image, class: 'Captain::MediaAssetImage' do
    sequence(:position)
    label { 'primary' }
    is_primary { false }

    after(:build) do |image|
      next if image.file.attached?

      image.file.attach(
        io: Rails.public_path.join('assets/images/dashboard/captain/logo.svg').open,
        filename: 'product.png',
        content_type: 'image/svg+xml'
      )
    end
  end

  factory :captain_media_asset, class: 'Captain::MediaAsset' do
    association :account
    association :assistant, factory: :captain_assistant, account: account
    sequence(:name) { |n| "Product #{n}" }
    currency { 'EUR' }
    price_cents { 89_000 }
    description { 'Sample catalog item' }
    tags { %w[gold ring] }
    active { true }

    after(:create) do |media_asset|
      next if media_asset.images.exists?

      create(
        :captain_media_asset_image,
        media_asset: media_asset,
        position: 0,
        label: 'primary',
        is_primary: true
      )
    end
  end
end
