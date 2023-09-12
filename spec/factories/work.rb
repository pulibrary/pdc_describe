# frozen_string_literal: true

FactoryBot.define do
  factory :work do
    transient do
      doi { "10.34770/#{format('%03d', rand(999))}-abc" }
      ark { nil }
    end
    factory :none_work do
      group { Group.research_data }
      state { "none" }
      created_by_user_id { FactoryBot.create(:user).id }
      resource { FactoryBot.build :resource, doi: doi }
    end

    factory :draft_work do
      group { Group.research_data }
      state { "draft" }
      created_by_user_id { FactoryBot.create(:user).id }
      resource { FactoryBot.build :resource, doi: doi, ark: ark }
    end

    factory :awaiting_approval_work do
      group { Group.research_data }
      state { "awaiting_approval" }
      created_by_user_id { FactoryBot.create(:user).id }
      resource { FactoryBot.build :resource, doi: doi, ark: ark }
    end

    factory :approved_work do
      group { Group.research_data }
      state { "approved" }
      created_by_user_id { FactoryBot.create(:user).id }
      resource { FactoryBot.build :resource, doi: doi, ark: ark }
    end

    factory :shakespeare_and_company_work do
      group { Group.research_data }
      resource do
        PDCMetadata::Resource.new_from_jsonb(
          {
            "doi" => "10.34770/pe9w-x904",
            "ark" => "ark:/88435/dsp01zc77st047",
            "identifier_type" => "DOI",
            "titles" => [{ "title" => "Shakespeare and Company Project Dataset: Lending Library Members, Books, Events" }],
            "description" =>
                                                "All data is related to the Shakespeare and Company bookshop and lending library opened and operated by Sylvia Beach in Paris, 1919–1962.",
            "creators" => [
              { "value" => "Kotin, Joshua", "name_type" => "Personal", "given_name" => "Joshua", "family_name" => "Kotin", "affiliations" => [], "sequence" => "1" }
            ],
            "resource_type" => "Dataset", "publisher" => "Princeton University", "publication_year" => "2020",
            "version_number" => "1",
            "rights" => { "identifier" => "CC BY" }
          }
        )
      end
      created_by_user_id { FactoryBot.create(:princeton_submitter).id }
    end

    factory :tokamak_work do
      group { Group.plasma_laboratory }
      resource do
        PDCMetadata::Resource.new_from_jsonb({
                                               "doi" => "10.34770/not_yet_assigned",
                                               "ark" => "ark:/88435/dsp015d86p342b",
                                               "identifier_type" => "DOI",
                                               "titles" => [{ "title" => "Electron Temperature Gradient Driven Transport Model for Tokamak Plasmas" }],
                                               "description" => "A new model for electron temperature gradient (ETG) modes is developed as a component of the Multi-Mode anomalous transport module.",
                                               "creators" => [
                                                 { "value" => "Rafiq, Tariq", "name_type" => "Personal", "given_name" => "Tariq", "family_name" => "Rafiq", "affiliations" => [], "sequence" => "1" }
                                               ],
                                               "resource_type" => "Dataset", "publisher" => "Princeton University", "publication_year" => "2022",
                                               "version_number" => "1",
                                               "rights" => { "identifier" => "CC BY" }
                                             })
      end
      created_by_user_id { FactoryBot.create(:pppl_submitter).id }
    end

    factory :tokamak_work_awaiting_approval do
      group { Group.plasma_laboratory }
      state { "awaiting_approval" }
      resource do
        PDCMetadata::Resource.new_from_jsonb({
                                               "doi" => "10.34770/not_yet_assigned",
                                               "ark" => "ark:/88435/dsp015d86p342b",
                                               "identifier_type" => "DOI",
                                               "titles" => [{ "title" => "Electron Temperature Gradient Driven Transport Model for Tokamak Plasmas" }],
                                               "description" => "A new model for electron temperature gradient (ETG) modes is developed as a component of the Multi-Mode anomalous transport module.",
                                               "creators" => [
                                                 { "value" => "Rafiq, Tariq", "name_type" => "Personal", "given_name" => "Tariq", "family_name" => "Rafiq", "affiliations" => [], "sequence" => "1" }
                                               ],
                                               "resource_type" => "Dataset", "publisher" => "Princeton University", "publication_year" => "2022",
                                               "version_number" => "1",
                                               "rights" => { "identifier" => "CC BY" }
                                             })
      end
      created_by_user_id { FactoryBot.create(:pppl_submitter).id }
    end

    factory :pppl_work_with_department_name_change do
      group { Group.plasma_laboratory }
      state { "awaiting_approval" }
      resource do
        json_from_spec = File.read(Rails.root.join("spec", "fixtures", "rename_pppl_dept1.json"))
        resource = JSON.parse(json_from_spec)["resource"]
        PDCMetadata::Resource.new_from_jsonb(resource)
      end
      created_by_user_id { FactoryBot.create(:pppl_submitter).id }
    end

    factory :sowing_the_seeds_work do
      title { "Sowing the Seeds for More Usable Web Archives: A Usability Study of Archive-It" }
      group { Group.research_data }
      doi { "" } # no DOI associated with this dataset
      ark { "ark:/88435/dsp01d791sj97j" }
      created_by_user_id { FactoryBot.create(:user).id }
    end

    # json_from_spec file created from the output of
    # spec/system/cytoskeletal_form_submission_spec.rb
    factory :distinct_cytoskeletal_proteins_work do
      group { Group.research_data }
      resource do
        json_from_spec = File.read(Rails.root.join("spec", "fixtures", "cytoskeletal_metadata.json"))
        PDCMetadata::Resource.new_from_jsonb(JSON.parse(json_from_spec))
      end
      state { "draft" }
      created_by_user_id { FactoryBot.create(:user).id }
    end

    factory :attention_and_awareness_work do
      title { "Attention and awareness in the dorsal attention network" }
      group { Group.research_data }
      doi { "https://doi.org/10.34770/9425-b553" }
      ark { "ark:/88435/dsp01xp68kk27p" }
      created_by_user_id { FactoryBot.create(:user).id }
    end

    factory :femtosecond_xray_work do
      title { "Femtosecond X-ray Diffraction of Laser-shocked Forsterite (Mg2SiO4) to 122 GPa" }
      group { Group.research_data }
      doi { "https://doi.org/10.34770/gg40-tc15" }
      ark { "ark:/88435/dsp01rj4307478" }
      created_by_user_id { FactoryBot.create(:user).id }
    end

    factory :bitklavier_work do
      title { "bitKlavier Grand Sample Library—Piano Bar Mic Image" }
      group { Group.research_data }
      doi { "https://doi.org/10.34770/r75s-9j74" }
      ark { "ark:/88435/dsp015999n653h" }
      created_by_user_id { FactoryBot.create(:user).id }
    end

    factory :design_and_simulation_of_the_snowflake_work do
      title { "Design and simulation of the snowflake divertor control for NSTX-U" }
      group { Group.research_data }
      doi { "" } # no DOI associated with this dataset
      ark { "ark:/88435/dsp01jm214r94t" }
      created_by_user_id { FactoryBot.create(:user).id }
    end

    factory :whistler_wave_generation_work do
      title { "Whistler wave generation by anisotropic tail electrons during asymmetric magnetic reconnection in space and laboratory" }
      group { Group.research_data }
      doi { "" } # no DOI associated with this dataset
      ark { "ark:/88435/dsp01t148fk89s" }
      created_by_user_id { FactoryBot.create(:user).id }
    end

    factory :supplemental_data_work do
      title { "Supplementary data for thesis: The Evolution and Regulation of Morphological Complexity in the Vibrios" }
      group { Group.research_data }
      doi { "https://doi.org/10.34770/gk6n-gj34" }
      ark { "ark:/88435/dsp01vq27zr562" }
      created_by_user_id { FactoryBot.create(:user).id }
    end
  end
end
