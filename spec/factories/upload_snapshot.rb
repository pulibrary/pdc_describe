# frozen_string_literal: true

FactoryBot.define do
  factory :upload_snapshot do
    url { "https://localhost.localdomain/file.txt" }
    version { 1 }
    work { FactoryBot.create(:approved_work) }
    files { [] }

    factory :upload_snapshot_with_illegal_characters do
      files do
        [
          {
            "filename" => "10.34770/tbd/4/laser width.xlsx",
            "checksum" => "dGFh+f5CnwifPlEhkT1Amg==",
            "migrate_status" => "started"
          },
          {
            "filename" => "10.34770/tbd/4/all OH LIF decays.xlsx",
            "checksum" => "oCovyV5XT+jNMsDbUpP/xA==",
            "migrate_status" => "started"
          },
          {
            "filename" => "10.34770/tbd/4/Dry He 2mm 10kV le=0.8mJ RH 50%.csv",
            "checksum" => "4sUs+2GkGPPFHgjyY3NsPw==",
            "migrate_status" => "started"
          },
          {
            "filename" => "10.34770/tbd/4/Dry He 2mm 20kV le=0.8mJ RH 50%.csv",
            "checksum" => "nY0PImdocFIffUu0oAIpoA==",
            "migrate_status" => "started"
          }
        ]
      end
    end
  end
end
