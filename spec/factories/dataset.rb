# frozen_string_literal: true

FactoryBot.define do
  factory :dataset do
    factory :sowing_the_seeds_dataset do
      doi { "" } # no DOI associated with this dataset
      ark { "ark:/88435/dsp01d791sj97j" }
      work { FactoryBot.create(:sowing_the_seeds_work) }
    end

    factory :distinct_cytoskeletal_proteins_dataset do
      doi { "https://doi.org/10.34770/r2dz-ys12" }
      ark { "ark:/88435/dsp01h415pd457" }
      work { FactoryBot.create(:distinct_cytoskeletal_proteins_work) }
    end

    factory :shakespeare_and_company_dataset do
      doi { "https://doi.org/10.34770/pe9w-x904" }
      ark { "ark:/88435/dsp01zc77st047" }
      work { FactoryBot.create(:shakespeare_and_company_work) }
    end

    factory :attention_and_awareness_dataset do
      doi { "https://doi.org/10.34770/9425-b553" }
      ark { "ark:/88435/dsp01xp68kk27p" }
      work { FactoryBot.create(:attention_and_awareness_work) }
    end

    factory :femtosecond_xray_dataset do
      doi { "https://doi.org/10.34770/gg40-tc15" }
      ark { "ark:/88435/dsp01rj4307478" }
      work { FactoryBot.create(:femtosecond_xray_work) }
    end

    factory :bitklavier_dataset do
      doi { "https://doi.org/10.34770/r75s-9j74" }
      ark { "ark:/88435/dsp015999n653h" }
      work { FactoryBot.create(:bitklavier_work) }
    end

    factory :design_and_simulation_of_the_snowflake_dataset do
      doi { "" } # no DOI associated with this dataset
      ark { "ark:/88435/dsp01jm214r94t" }
      work { FactoryBot.create(:design_and_simulation_of_the_snowflake_work) }
    end

    factory :whistler_wave_generation_dataset do
      doi { "" } # no DOI associated with this dataset
      ark { "ark:/88435/dsp01t148fk89s" }
      work { FactoryBot.create(:whistler_wave_generation_work) }
    end

    factory :supplemental_data_dataset do
      doi { "https://doi.org/10.34770/gk6n-gj34" }
      ark { "ark:/88435/dsp01vq27zr562" }
      work { FactoryBot.create(:supplemental_data_work) }
    end
  end
end
