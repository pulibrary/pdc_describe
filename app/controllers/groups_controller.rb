# frozen_string_literal: true
class GroupsController < CollectionsController
  private

    # Only allow trusted parameters through.
    def collection_params
      params.require(:group).permit([:title, :description])
    end
end
