This readme.txt file was created on 2020-07 by Rebecca Sutton Koeser; reviewed by Joshua Kotin


GENERAL INFORMATION


1. Title of Dataset: Shakespeare and Company Project Dataset: Lending Library Members, Books, Events


2. Author Information
        A. Principal Investigator Contact Information
                Name: Joshua Kotin
                Institution: Princeton University
                Email: jkotin@princeton.edu


        B. Associate or Co-investigator Contact Information
                Name: Rebecca Sutton Koeser
                Institution: Princeton University
                Email: rkoeser@princeton.edu


        C. Alternate Contact Information
                Name: Center for Digital Humanities
                Institution: Princeton University
                Email: cdh-info@princeton.edu


3. Date of data transcription, processing, and refinement: 2015-04 through 2020-07


4. Information about funding sources that supported the collection of the data:


The Shakespeare and Company Project has received support from Princeton University’s Center for Digital Humanities; Humanities Council and the David A. Gardner ’69 Magic Project Fund; University Committee on Research in the Humanities and Social Sciences; the Dean’s Innovation Fund for New Ideas in the Humanities; the Bain-Swiggett Fund, Department of English; and the Princeton-Mellon Initiative in Architecture, Urbanism, and the Humanities.




SHARING/ACCESS INFORMATION


1. Licenses/restrictions placed on the data:


Dataset is released under the Creative Commons Attribution 4.0 license (CC-BY-4.0): https://creativecommons.org/licenses/by/4.0/


3. Links to other publicly accessible locations of the data:
Current versions of this dataset available at https://shakespeareandco.princeton.edu/about/data/


4. Links/relationships to ancillary data sets:
Information about lending library members, books, and events are available in separate datasets that can be used individually or together. All datasets use Shakespeare and Company Project URLs as consistent identifiers for books and members.

Members: https://doi.org/10.34770/ht30-g395 
Books: https://doi.org/10.34770/g467-3w07 
Events: https://doi.org/10.34770/2r93-0t85 


5. Was data derived from another source? Yes, datasets are exported from the Shakespeare and Company Project:


        Shakespeare and Company Project, version 1.2.0. Center for Digital Humanities, Princeton University, 2019. https://shakespeareandco.princeton.edu. Accessed 13 July 2020.


6. Recommended citation for this dataset:


Kotin, Joshua, Rebecca Sutton Koeser, Carl Adair, Serena Alagappan, Jean Bauer, Oliver J. Browne, Nick Budak, Harriet Calver, Jin Chow, Ian Davis, Gissoo Doroudian, Currie Engel, Elspeth Green, Benjamin Hicks, Madeleine E. Joelson, Carolyn Kelly, Sara Krolewski, Xinyi Li, Ellie Maag, Cate Mahoney, Jesse D. McCarthy, Mary Naydan, Isabel Ruehl, Sylvie Thode, Camey VanSant, and Clifford E. Wulfman. Shakespeare and Company Project Dataset: Lending Library Members, Books, Events. Version 1.0. July 2020. Distributed by DataSpace, Princeton University. https://doi.org/10.34770/pe9w-x904 


DATA & FILE OVERVIEW


All data is related to the Shakespeare and Company bookshop and lending library opened and operated by Sylvia Beach in Paris.


1. File List:


SCoData_members_v1_2020-07.csv : lending library members
SCoData_members_v1_2020-07.json : lending library members (JSON)
SCoData_books_v1_2020-07.csv : books that circulated
SCoData_books_v1_2020-07.json : books that circulated (JSON)
SCoData_events_v1_2020-07.csv : events (subscriptions, renewals, reimbursements, borrowing, purchasing, etc)
SCoData_events_v1_2020-07.json : events (JSON)
SCoData_combined_v1_2020-07_datapackage.json : frictionless data (https://frictionlessdata.io/) data package schema description for all CSV files


2. Relationship between files, if important:
CSV and JSON files with the same name have exactly the same content.
All files use member and book URIs from the Shakespeare and Company Project site https://shakespeareandco.princeton.edu as identifiers for cross-referencing data.


3. Are there multiple versions of the dataset?
Not yet, but we anticipate releasing new versions as more data is added or corrections are made.


DATA-SPECIFIC INFORMATION FOR:
SCoData_members_v1_2020-07.csv, SCoData_members_v1_2020-07.json


1. Number of fields: 19


2. Number of rows: 5726


3. Field List:
uri : identifier; member detail page on https://shakespeareandco.princeton.edu
name : full name; may include variant names, name as written on lending library card; for more, see https://shakespeareandco.princeton.edu/about/faq/#names
sort_name : authorized name
title : honorific address if known, e.g. Mr., Mrs. etc.
gender : Male, Female, Nonbinary, Unknown; for more, see https://shakespeareandco.princeton.edu/about/faq/#gender
is_organization : member is an organization instead of a person (boolean)
has_card : member has an extant lending library card (boolean)
birth_year : birth year, if known
death_year :  death year, if known
membership_years :  list of known active membership years (multiple, separated by semicolons)
viaf_url : URL for Virtual Internet Authority File (VIAF, https://viaf.org/) identifier, if known
wikipedia_url : URL for Wikipedia page, if known
nationalities : countries for known nationality (multiple, separated by semicolons)
addresses : list of known addresses (multiple, separated by semicolons)
postal_codes : list of postal addresses from addresses (multiple, separated by semicolons; order matches addresses)
arrondissements : list of Paris arrondissements (integer; multiple, separated by semicolons; order matches addresses)
coordinates : list of geographical coordinates for known addresses (pairs of latitude, longitude; multiple, separated by semicolons; order matches addresses)
notes : more information (text with markdown formatting)
updated : timestamp record was last modified in the Shakespeare and Company Project database before export


4. Missing data codes:
Fields with no information are left blank.




DATA-SPECIFIC INFORMATION FOR:
SCoData_books_v1_2020-07.csv, SCoData_books_v1_2020-07.json


1. Number of fields: 21


2. Number of rows: 6,011


3. Field List:
uri : identifier; book detail page on https://shakespeareandco.princeton.edu
title : title of the book or other item
author : author or authors, last name first (could be multiple; separated by semicolon)
editor : editor(s)
contributor : contributor(s)
translator : translator(s)
illustrator : illustrator(s)
introduction : author of an introduction
preface : author of a preface
photographer : photographer
year : year published
format : type of item (Book, Periodical, Article)
uncertain : boolean indicating if item is ambiguous or unidentifiable
ebook_url : link to a digital edition of this work
volumes_issues : list of multivolume volumes or periodical issues known to have circulated (separated by semicolon)
notes : more information, e.g. about uncertain titles (text with markdown formatting)
event_count : total number of events associated with this title (integer)
borrow_count : total number of borrowing events associated with this title (integer)
purchase_count : total number of purchase events associated with this title (integer)
circulation_years :  list of years of known activity for this title (multiple, separated by semicolon)
updated : timestamp record was last modified in the Shakespeare and Company Project database before export


4. Missing data codes:
Fields with no information are left blank.






DATA-SPECIFIC INFORMATION FOR:
SCoData_events_v1_2020-07.csv, SCoData_events_v1_2020-07.json


1. Number of fields: 26


2. Number of rows: 33,741


3. Field List:
event_type : type of event
start_date :  start date, if known (ISO 8601 format; YYYY, YY-MM, YYYY-MM-DD, or -MM-DD)
end_date : end date, if known (ISO 8601 format; YYYY, YY-MM, YYYY-MM-DD, or -MM-DD)
member_uris : list of URIs for members associated with this event (could be multiple, separated by semicolons)
member_names : list of full member names with variants (multiple, separated by semicolons; order matches member_uris)
member_sort_names : list of member authorized sort names (multiple, separated by semicolons; order matches member_uris)
subscription_price_paid : amount paid for a subscription event (numeric)
subscription_deposit : amount deposited for a new subscription (numeric)
subscription_duration :  logical subscription duration (human readable, e.g. 6 months, 1 year)
subscription_duration_days : actual subscription duration in days (integer)
subscription_volumes : number of volumes paid for in the subscription
subscription_category : subscription plan, if any; see https://shakespeareandco.princeton.edu/about/faq/#lending-library-plans
subscription_purchase_date : date the subscription was purchased (ISO 8601 format; YYYY, YY-MM, YYYY-MM-DD, or -MM-DD)
reimbursement_refund : amount refunded for a reimbursement event (numeric)
borrow_status : status code indicating how a borrowing event ended (Returned, Bought, Missing, Unknown)
purchase_price : amount paid for a purchase
currency :  currency code indicating currency of subscription price paid, deposit, reimbursement refund, or purchase price (ISO 4217 currency code)
item_uri : identifier for book associated with this event, if there is one
item_title : title of the book associated with this event
item_volume : volume / issue information for this event, if item is a multivolume work or periodical and volume/issue information is known
item_authors : list of authors for this work; authorized names, last name first (could be multiple; separated by semicolon)
item_year : publication year
item_notes : notes about the item
source_citation : bibliographic citation for the source of this data, if known (generally available for borrow and purchase events only)
source_manifest : IIIF Presentation manifest URL for a digitized edition of the source of this data
source_image : IIIF Image URL for the digitized image in the IIIF manifest documenting this event, if known


4. Missing data codes:
Fields with no information are left blank.
Partially known dates use ISO 8601 format to convey as much of the date as is known; dates include month/day without known year in --MM-DD format.


NOTE: Duplicate rows in the dataset are not errors. Lending library members occasionally borrowed multiple copies of the same periodical and bought multiple copies of the same book.