# frozen_string_literal: true

# Encapsulate the logic for finding various lists of works
#   Extracted from the work class to stem the ever growing size of the Work Class
class WorkList
  class << self
    def unfinished_works(user, search_terms = nil)
      works_by_user_state(user, ["none", "draft", "awaiting_approval"], search_terms)
    end

    def completed_works(user, search_terms = nil)
      works_by_user_state(user, "approved", search_terms)
    end

    def withdrawn_works(user, search_terms = nil)
      works_by_user_state(user, "withdrawn", search_terms)
    end

    private

      def search_terms_where_clause(search_terms)
        if search_terms.nil?
          Work.all
        else
          Work.where("CAST(metadata AS VARCHAR) ILIKE :search_terms", search_terms: "%" + search_terms.strip + "%")
        end
      end

      def works_by_user_state(user, state, search_terms)
        search_context = search_terms_where_clause(search_terms)

        # The user's own works (if any) by state and search terms
        works = search_context.where(created_by_user_id: user, state: state).to_a

        if user.admin_groups.count > 0
          # The works that match the given state, in all the groups the user can admin
          # (regardless of who created those works)
          user.admin_groups.each do |group|
            works += search_context.where(group_id: group.id, state: state)
          end
        end

        # Any other works where the user is mentioned
        works_mentioned_by_user_state(user, state, search_context).each do |work|
          already_included = !works.find { |existing_work| existing_work[:id] == work.id }.nil?
          works << work unless already_included
        end

        works.uniq(&:id).sort_by(&:updated_at).reverse
      end

      # Returns an array of work ids where a particular user has been mentioned
      # and the work is in a given state.
      def works_mentioned_by_user_state(user, state, search_context)
        search_context.joins(:work_activity)
                      .joins('INNER JOIN "work_activity_notifications" ON "work_activities"."id" = "work_activity_notifications"."work_activity_id"')
                      .where(state: state)
                      .where('"work_activity_notifications"."user_id" = ?', user.id)
      end
  end
end
