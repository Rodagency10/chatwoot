class Api::V1::Accounts::Captain::MediaAssetsController < Api::V1::Accounts::BaseController
  before_action :current_account
  before_action -> { check_authorization(Captain::Assistant) }

  before_action :set_current_page, only: [:index]
  before_action :set_media_assets, except: [:create]
  before_action :set_media_asset, only: [:show, :update, :destroy]
  before_action :set_assistant, only: [:create]

  RESULTS_PER_PAGE = 24

  def index
    base_query = @media_assets
    base_query = base_query.where(assistant_id: permitted_params[:assistant_id]) if permitted_params[:assistant_id].present?
    base_query = base_query.search(permitted_params[:search_key]) if permitted_params[:search_key].present?
    base_query = base_query.where(active: true) if ActiveModel::Type::Boolean.new.cast(permitted_params[:active_only])

    @media_assets_count = base_query.count
    @media_assets = base_query.with_attached_image.ordered.page(@current_page).per(RESULTS_PER_PAGE)
  end

  def show; end

  def create
    return render_could_not_create_error('Missing Assistant') if @assistant.nil?

    @media_asset = @assistant.media_assets.build(media_asset_params)
    @media_asset.account = Current.account
    @media_asset.save!
  rescue ActiveRecord::RecordInvalid => e
    render_could_not_create_error(e.record.errors.full_messages.join(', '))
  end

  def update
    @media_asset.update!(media_asset_params)
  rescue ActiveRecord::RecordInvalid => e
    render_could_not_create_error(e.record.errors.full_messages.join(', '))
  end

  def destroy
    @media_asset.destroy
    head :no_content
  end

  private

  def set_media_assets
    @media_assets = Current.account.captain_media_assets.includes(:assistant)
  end

  def set_media_asset
    @media_asset = @media_assets.find(permitted_params[:id])
  end

  def set_assistant
    @assistant = Current.account.captain_assistants.find_by(id: media_asset_params[:assistant_id])
  end

  def set_current_page
    @current_page = permitted_params[:page] || 1
  end

  def permitted_params
    params.permit(:assistant_id, :page, :id, :account_id, :search_key, :active_only)
  end

  def media_asset_params
    params.require(:media_asset).permit(
      :name, :sku, :price_cents, :currency, :description, :active, :position, :assistant_id, :image, tags: []
    )
  end
end
