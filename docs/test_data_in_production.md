# How to move data from test fixtures to production

One of our goals for data migration is to have 5 - 10 sample objects that we have:
* Validated description in our submission form
* Solid, well tested indexing and display in PDC Discovery

In order to deliver this, we will:
* Describe representative test records using rspec system specs (see, e.g., `spec/system/bitklavier_form_submission_spec.rb`)
* Validate the DataCite records that are produced by that system spec with our data curators
* Move the metadata produced by that system spec into our staging system
* That will give us a known and consistent target to work with as we zero in on how to index these works for PDC Discovery.

## Process

### 1. Create a system spec
Work with RDOS to ensure we're identifying representative samples. We want to cover a range of use cases (e.g., works that have a DOI already, works that have a DOI from PPPL, works that do not have DOI yet and will mint one upon migration).

### 2. Update system specs as needed
These will need to be kept updated with changes to the UI, changes to the metadata schema, etc.

### 3. Create or refresh the work in staging
Enter a `byebug` at the end of the system spec for the sample work you want to refresh, then run the test. It will drop you into a prompt where you can get the JSON export of the work.
```ruby
(byebug) bitklavier_work.to_json
"{\"titles\":[{\"title\":\"bitKlavier Grand Sample Library—Binaural Mic Image\",\"title_type\":null}],\"description\":\"The bitKlavier Grand consists of sample collections of a new Steinway D grand piano from nine different stereo mic images, with: 16 velocity layers, at every minor 3rd (starting at A0); Hammer release samples; Release resonance samples; Pedal samples. Release packages at 96k/24bit, 88.2k/24bit, 48k/24bit, 44.1k/16bit are available for various applications.\\r\\n  Piano Bar: Earthworks—omni-directionals. This microphone system suspends omnidirectional microphones within the piano. The bar is placed across the harp near the hammers and provides a low string / high string player’s perspective. It also produces a close sound without room or lid interactions. It can be panned across an artificial stereophonic perspective effectively in post-production. File Naming Convention: C4 = middle C. Main note names: [note name][octave]v[velocity].wav -- e.g., “D#5v13.wav”. Release resonance notes: harm[note name][octave]v[velocity].wav -- e.g., “harmC2v2.wav”. Hammer samples: rel[1-88].wav (one per key) -- e.g., “rel23.wav”. Pedal samples: pedal[D/U][velocity].wav -- e.g., “pedalU2.wav” =\\u003e pedal release (U = up), velocity = 2 (quicker release than velocity = 1).\\r\\n  This dataset is too large to download directly from this item page. You can access and download the data via Globus (See https://www.youtube.com/watch?v=uf2c7Y1fiFs for instructions on how to use Globus).\",\"collection_tags\":[],\"creators\":[{\"value\":\"Trueman, Daniel\",\"name_type\":\"Personal\",\"given_name\":\"Daniel\",\"family_name\":\"Trueman\",\"identifier\":null,\"affiliations\":[],\"sequence\":1},{\"value\":\"Wang, Matthew\",\"name_type\":\"Personal\",\"given_name\":\"Matthew\",\"family_name\":\"Wang\",\"identifier\":null,\"affiliations\":[],\"sequence\":2},{\"value\":\"Villalta, Andrés\",\"name_type\":\"Personal\",\"given_name\":\"Andrés\",\"family_name\":\"Villalta\",\"identifier\":null,\"affiliations\":[],\"sequence\":3},{\"value\":\"Chou, Katie\",\"name_type\":\"Personal\",\"given_name\":\"Katie\",\"family_name\":\"Chou\",\"identifier\":null,\"affiliations\":[],\"sequence\":4},{\"value\":\"Ayres, Christien\",\"name_type\":\"Personal\",\"given_name\":\"Christien\",\"family_name\":\"Ayres\",\"identifier\":null,\"affiliations\":[],\"sequence\":5}],\"resource_type\":\"Dataset\",\"resource_type_general\":\"DATASET\",\"publisher\":\"Princeton University\",\"publication_year\":\"2021\",\"ark\":\"88435/dsp015999n653h\",\"doi\":\"10.34770/r75s-9j74\",\"rights\":{\"identifier\":\"CC BY\",\"uri\":\"https://creativecommons.org/licenses/by/4.0/\",\"name\":\"Creative Commons Attribution 4.0 International\"},\"version_number\":\"1\",\"keywords\":[]}"
```

That JSON can now be copied and pasted onto a rails console:

```ruby
 bess@dali  ~/projects/pdc_describe   sample_data_in_production ±  be rails c
Running via Spring preloader in process 35341
Loading development environment (Rails 6.1.6.1)
[1] pry(main)> bit_json = "{\"titles\":[{\"title\":\"bitKlavier Grand Sample Library—Binaural Mic Image\",\"title_type\":null}],\"description\":\"The bitKlavier Grand consists of sample collections of a new Steinway D grand piano from nine different stereo mic images, with: 16 velocity layers, at every minor 3rd (starting at A0); Hammer release samples; Release resonance samples; Pedal samples. Release packages at 96k/24bit, 88.2k/24bit, 48k/24bit, 44.1k/16bit are available for various applications.\\r\\n  Piano Bar: Earthworks—omni-directionals. This microphone system suspends omnidirectional microphones within the piano. The bar is placed across the harp near the hammers and provides a low string / high string player’s perspective. It also produces a close sound without room or lid interactions. It can be panned across an artificial stereophonic perspective effectively in post-production. File Naming Convention: C4 = middle C. Main note names: [note name][octave]v[velocity].wav -- e.g., “D#5v13.wav”. Release resonance notes: harm[note name][octave]v[velocity].wav -- e.g., “harmC2v2.wav”. Hammer samples: rel[1-88].wav (one per key) -- e.g., “rel23.wav”. Pedal samples: pedal[D/U][velocity].wav -- e.g., “pedalU2.wav” =\\u003e pedal release (U = up), velocity = 2 (quicker release than velocity = 1).\\r\\n  This dataset is too large to download directly from this item page. You can access and download the data via Globus (See https://www.youtube.com/watch?v=uf2c7Y1fiFs for instructions on how to use Globus).\",\"collection_tags\":[],\"creators\":[{\"value\":\"Trueman, Daniel\",\"name_type\":\"Personal\",\"given_name\":\"Daniel\",\"family_name\":\"Trueman\",\"identifier\":null,\"affiliations\":[],\"sequence\":1},{\"value\":\"Wang, Matthew\",\"name_type\":\"Personal\",\"given_name\":\"Matthew\",\"family_name\":\"Wang\",\"identifier\":null,\"affiliations\":[],\"sequence\":2},{\"value\":\"Villalta, Andrés\",\"name_type\":\"Personal\",\"given_name\":\"Andrés\",\"family_name\":\"Villalta\",\"identifier\":null,\"affiliations\":[],\"sequence\":3},{\"value\":\"Chou, Katie\",\"name_type\":\"Personal\",\"given_name\":\"Katie\",\"family_name\":\"Chou\",\"identifier\":null,\"affiliations\":[],\"sequence\":4},{\"value\":\"Ayres, Christien\",\"name_type\":\"Personal\",\"given_name\":\"Christien\",\"family_name\":\"Ayres\",\"identifier\":null,\"affiliations\":[],\"sequence\":5}],\"resource_type\":\"Dataset\",\"resource_type_general\":\"DATASET\",\"publisher\":\"Princeton University\",\"publication_year\":\"2021\",\"ark\":\"88435/dsp015999n653h\",\"doi\":\"10.34770/r75s-9j74\",\"rights\":{\"identifier\":\"CC BY\",\"uri\":\"https://creativecommons.org/licenses/by/4.0/\",\"name\":\"Creative Commons Attribution 4.0 International\"},\"version_number\":\"1\",\"keywords\":[]}"
```

Then, ssh to the server where you want to create this sample work as the `deploy` user. Open a rails console and make the object there:

```ruby
irb(main):002:0> bitklavier_resource = PDCMetadata::Resource.new_from_json("{\"titles\":[{\"title\":\"bitKlavier Grand Sample Library—Binaural Mic Image\",\"title_type\
":null}],\"description\":\"The bitKlavier Grand consists of sample collections of a new Steinway D grand piano from nine different stereo mic images, with: 16 velocity
layers, at every minor 3rd (starting at A0); Hammer release samples; Release resonance samples; Pedal samples. Release packages at 96k/24bit, 88.2k/24bit, 48k/24bit, 44
.1k/16bit are available for various applications.\\r\\n  Piano Bar: Earthworks—omni-directionals. This microphone system suspends omnidirectional microphones within the
 piano. The bar is placed across the harp near the hammers and provides a low string / high string player’s perspective. It also produces a close sound without room or
lid interactions. It can be panned across an artificial stereophonic perspective effectively in post-production. File Naming Convention: C4 = middle C. Main note names:
 [note name][octave]v[velocity].wav -- e.g., “D#5v13.wav”. Release resonance notes: harm[note name][octave]v[velocity].wav -- e.g., “harmC2v2.wav”. Hammer samples: rel[
1-88].wav (one per key) -- e.g., “rel23.wav”. Pedal samples: pedal[D/U][velocity].wav -- e.g., “pedalU2.wav” =\\u003e pedal release (U = up), velocity = 2 (quicker rele
ase than velocity = 1).\\r\\n  This dataset is too large to download directly from this item page. You can access and download the data via Globus (See https://www.yout
ube.com/watch?v=uf2c7Y1fiFs for instructions on how to use Globus).\",\"collection_tags\":[],\"creators\":[{\"value\":\"Trueman, Daniel\",\"name_type\":\"Personal\",\"g
iven_name\":\"Daniel\",\"family_name\":\"Trueman\",\"identifier\":null,\"affiliations\":[],\"sequence\":1},{\"value\":\"Wang, Matthew\",\"name_type\":\"Personal\",\"giv
en_name\":\"Matthew\",\"family_name\":\"Wang\",\"identifier\":null,\"affiliations\":[],\"sequence\":2},{\"value\":\"Villalta, Andrés\",\"name_type\":\"Personal\",\"give
n_name\":\"Andrés\",\"family_name\":\"Villalta\",\"identifier\":null,\"affiliations\":[],\"sequence\":3},{\"value\":\"Chou, Katie\",\"name_type\":\"Personal\",\"given_n
ame\":\"Katie\",\"family_name\":\"Chou\",\"identifier\":null,\"affiliations\":[],\"sequence\":4},{\"value\":\"Ayres, Christien\",\"name_type\":\"Personal\",\"given_name\":\"Christien\",\"family_name\":\"Ayres\",\"identifier\":null,\"affiliations\":[],\"sequence\":5}],\"resource_type\":\"Dataset\",\"resource_type_general\":\"DATASET\",\"publisher\":\"Princeton University\",\"publication_year\":\"2021\",\"ark\":\"88435/dsp015999n653h\",\"doi\":\"10.34770/r75s-9j74\",\"rights\":{\"identifier\":\"CC BY\",\"uri\":\"https://creativecommons.org/licenses/by/4.0/\",\"name\":\"Creative Commons Attribution 4.0 International\"},\"version_number\":\"1\",\"keywords\":[]}")
=>
#<PDCMetadata::Resource:0x000055ad4be0e428
...
irb(main):003:0> work = Work.new(resource: bitklavier_resource)
=>
#<Work:0x000055ad4cea22a8
...
irb(main):004:0> work.collection = Collection.research_data
=>
#<Collection:0x000055ad4d2497d0
...
irb(main):013:0> work.created_by_user_id = User.find_by_uid('bs3097').id
=> 3
work.state = 'draft'
=> "draft"
irb(main):005:0> work.save
=> true
```

The work should now be visible in the application.