class TableSessionsController < ApplicationController
  def show
    table = normalize_table(params[:identifier])
    if table.blank?
      redirect_to root_path, alert: "Identificador de mesa inválido."
      return
    end

    session[:table_number] = table
    session[:return_to] = nil

    redirect_to products_path, notice: "Mesa #{table} vinculada. Faça seu pedido."
  end

  private

  def normalize_table(raw)
    value = raw.to_s.upcase.gsub(/[^A-Z0-9]/, "")
    return nil if value.blank?

    if value.match?(/\A\d+\z/)
      "MESA #{value.rjust(2, "0")}"
    elsif value.start_with?("MESA")
      suffix = value.delete_prefix("MESA").strip
      return nil if suffix.blank?

      "MESA #{suffix}"
    else
      "MESA #{value}"
    end
  end
end
