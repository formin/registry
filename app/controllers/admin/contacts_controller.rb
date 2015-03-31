class Admin::ContactsController < AdminController
  load_and_authorize_resource
  before_action :set_contact, only: [:show]

  def index
    @q = Contact.includes(:registrar).search(params[:q])
    @contacts = @q.result.page(params[:page])
  end

  def search
    render json: Contact.search_by_query(params[:q])
  end

  private

  def set_contact
    @contact = Contact.includes(domains: :registrar).find(params[:id])
  end
end
