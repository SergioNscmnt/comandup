module Admin
  class CategoriesController < BaseController
    before_action :set_category, only: [:edit, :update]

    def new
      @category = Category.new
      render layout: false
    end

    def create
      @category = Category.new(category_params)

      if @category.save
        redirect_to products_path, notice: "Categoria criada com sucesso."
      else
        flash.now[:alert] = @category.errors.full_messages.to_sentence
        render :new, status: :unprocessable_entity, layout: false
      end
    end

    def edit
      render layout: false
    end

    def update
      if @category.update(category_params)
        redirect_to products_path, notice: "Categoria atualizada com sucesso."
      else
        flash.now[:alert] = @category.errors.full_messages.to_sentence
        render :edit, status: :unprocessable_entity, layout: false
      end
    end

    def reorder
      ids = params[:category_ids].to_a.map(&:to_i).uniq
      existing_ids = Category.where(id: ids).pluck(:id)

      if ids.blank? || existing_ids.sort != ids.sort
        render json: { error: "Lista de categorias inválida." }, status: :unprocessable_entity
        return
      end

      Category.transaction do
        ids.each_with_index do |id, index|
          Category.where(id: id).update_all(position: index + 1, updated_at: Time.current)
        end
      end

      render json: { ok: true }
    end

    private

    def set_category
      @category = Category.find(params[:id])
    end

    def category_params
      params.require(:category).permit(:name, :position)
    end
  end
end
