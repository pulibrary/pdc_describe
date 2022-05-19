# frozen_string_literal: true

FactoryBot.define do
  factory :work do
    factory :shakespeare_and_company_work do
      title { "Shakespeare and Company Project Dataset: Lending Library Members, Books, Events" }
      collection { Collection.research_data }
      doi { "https://doi.org/10.34770/pe9w-x904" }
      ark { "ark:/88435/dsp01zc77st047" }
      data_cite do
        # Works must have at least one creator
        datacite_resource = Datacite::Resource.new
        datacite_resource.creators << Datacite::Creator.new_person("Harriet", "Tubman")
        datacite_resource.to_json
      end
      created_by_user_id { FactoryBot.create(:user).id }
    end

    factory :sowing_the_seeds_work do
      title { "Sowing the Seeds for More Usable Web Archives: A Usability Study of Archive-It" }
      collection { Collection.research_data }
      doi { "" } # no DOI associated with this dataset
      ark { "ark:/88435/dsp01d791sj97j" }
      created_by_user_id { FactoryBot.create(:user).id }
    end

    factory :distinct_cytoskeletal_proteins_work do
      title { "Distinct cytoskeletal proteins define zones of enhanced cell wall synthesis in Helicobacter pylori" }
      collection { Collection.research_data }
      doi { "https://doi.org/10.34770/r2dz-ys12" }
      ark { "ark:/88435/dsp01h415pd457" }
      created_by_user_id { FactoryBot.create(:user).id }
    end

    factory :attention_and_awareness_work do
      title { "Attention and awareness in the dorsal attention network" }
      collection { Collection.research_data }
      doi { "https://doi.org/10.34770/9425-b553" }
      ark { "ark:/88435/dsp01xp68kk27p" }
      created_by_user_id { FactoryBot.create(:user).id }
    end

    factory :femtosecond_xray_work do
      title { "Femtosecond X-ray Diffraction of Laser-shocked Forsterite (Mg2SiO4) to 122 GPa" }
      collection { Collection.research_data }
      doi { "https://doi.org/10.34770/gg40-tc15" }
      ark { "ark:/88435/dsp01rj4307478" }
      created_by_user_id { FactoryBot.create(:user).id }
    end

    factory :bitklavier_work do
      title { "bitKlavier Grand Sample Library—Piano Bar Mic Image" }
      collection { Collection.research_data }
      doi { "https://doi.org/10.34770/r75s-9j74" }
      ark { "ark:/88435/dsp015999n653h" }
      created_by_user_id { FactoryBot.create(:user).id }
    end

    factory :design_and_simulation_of_the_snowflake_work do
      title { "Design and simulation of the snowflake divertor control for NSTX-U" }
      collection { Collection.research_data }
      doi { "" } # no DOI associated with this dataset
      ark { "ark:/88435/dsp01jm214r94t" }
      created_by_user_id { FactoryBot.create(:user).id }
    end

    factory :whistler_wave_generation_work do
      title { "Whistler wave generation by anisotropic tail electrons during asymmetric magnetic reconnection in space and laboratory" }
      collection { Collection.research_data }
      doi { "" } # no DOI associated with this dataset
      ark { "ark:/88435/dsp01t148fk89s" }
      created_by_user_id { FactoryBot.create(:user).id }
    end

    factory :supplemental_data_work do
      title { "Supplementary data for thesis: The Evolution and Regulation of Morphological Complexity in the Vibrios" }
      collection { Collection.research_data }
      doi { "https://doi.org/10.34770/gk6n-gj34" }
      ark { "ark:/88435/dsp01vq27zr562" }
      created_by_user_id { FactoryBot.create(:user).id }
    end

    factory :us_national_pandemic_report_work do
      title { "The U.S. National Pandemic Emotional Impact Report" }
      ark { "ark:/88435/dsp01h415pd635" }
      collection { FactoryBot.create(:library_resources) }
      created_by_user_id { FactoryBot.create(:user).id }
    end

    factory :fortune_100_blm_work do
      title { "The Fortune 100 and Black Lives Matter" }
      ark { "ark:/88435/dsp01hh63t004k" }
      collection { FactoryBot.create(:library_resources) }
      created_by_user_id { FactoryBot.create(:user).id }
    end

    factory :racial_wealth_gap_work do
      title { "The racial wealth gap: Why policy matters" }
      ark { "ark:/88435/dsp012z10wt38q" }
      collection { FactoryBot.create(:library_resources) }
      created_by_user_id { FactoryBot.create(:user).id }
    end

    factory :hungary_around_clock_work do
      title { "Hungary around the clock, January 5, 2022" }
      ark { "ark:/88435/dsp01w37639913" }
      collection { FactoryBot.create(:library_resources) }
      created_by_user_id { FactoryBot.create(:user).id }
    end

    factory :gu_dian_yan_jiu_work do
      title { "Gu dian yan jiu 古典研究; No. 9 (Spring 2012)" }
      ark { "ark:/88435/dsp01fx719q54q" }
      collection { FactoryBot.create(:library_resources) }
      created_by_user_id { FactoryBot.create(:user).id }
    end

    factory :racism_inequality_health_care_work do
      title { "Racism, inequality, and health care for African Americans" }
      ark { "ark:/88435/dsp01ng451m58f" }
      collection { FactoryBot.create(:library_resources) }
      created_by_user_id { FactoryBot.create(:user).id }
    end

    factory :national_health_ukraine_work do
      title { "Nat︠s︡ional'ni rakhunky okhorony zdorov'i︠a︡ v Ukraïni u 2016 rot︠s︡i" }
      ark { "ark:/88435/dsp01zk51vk539" }
      collection { FactoryBot.create(:library_resources) }
      created_by_user_id { FactoryBot.create(:user).id }
    end
  end
end
