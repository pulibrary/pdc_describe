require "rails_helper"

describe "walk the wizard in reverse", type: :system do
    let(:user) { FactoryBot.create(:princeton_submitter) }
    
    it "goes to the correct pages" do 
        work = FactoryBot.create :draft_work
        sign_in user
        visit work_review_path(work)

        expect(page).to have_content "Data curators will review"
        click_on "Go Back"

        expect(page).to have_content "Begin the process to upload your submission"
        click_on "Go Back"

        expect(page).to have_content "Please upload the README"
        click_on "Go Back"

        expect(page).to have_content "By initiating this new submission"
        click_on "Save Work"
        
        expect(page).to have_content "Please upload the README"
        click_on "Save Work"

        expect(page).to have_content "Begin the process to upload your submission"
        click_on "Save Work"

        expect(page).to have_content "Data curators will review"
    end

end
