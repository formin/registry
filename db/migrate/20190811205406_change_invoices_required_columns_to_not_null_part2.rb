class ChangeInvoicesRequiredColumnsToNotNullPart2 < ActiveRecord::Migration[6.0]
  def change
    change_column_null :invoices, :seller_email, false
    change_column_null :invoices, :seller_contact_name, false
    change_column_null :invoices, :buyer_email, false
  end
end
