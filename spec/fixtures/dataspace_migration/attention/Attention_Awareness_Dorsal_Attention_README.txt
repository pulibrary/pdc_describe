This Attention_Awareness_Dorsal_Attention_readme.txt file was generated on 2020-11-17 by Andrew I. Wilterson


GENERAL INFORMATION

1. Title of Dataset: Attention and Awareness Interact in the Dorsal Attention Network

2. Author Information
	A. Principal Investigator Contact Information
		Name: Michael Graziano
		Institution: Princeton University
		Address: 281 Princeton Neuroscience Institute
		Email: graziano@princeton.edu

	B. Associate or Co-investigator Contact Information
		Name: Andrew Wilterson
		Institution: Princeton University
		Address: 
		Email: andrew.wilterson@princeton.edu

	C. Alternate Contact Information
		Name: 
		Institution: 
		Address: 
		Email: 

3. Date of data collection (single date, range, approximate date): 2019-05-10 - 2019-11-14

4. Geographic location of data collection: Princeton, New Jersey, United States

5. Information about funding sources that supported the collection of the data: Princeton Neuroscience Institute Innovation Fund


SHARING/ACCESS INFORMATION

1. Licenses/restrictions placed on the data: N/A

2. Links to publications that cite or use the data: TBD

3. Links to other publicly accessible locations of the data: N/A

4. Links/relationships to ancillary data sets: N/A

5. Was data derived from another source? no
	A. If yes, list source(s): 

6. Recommended citation for this dataset: Wilterson, A.I., Nastase, S.A., Bio, B.J., Guterstam, A., Graziano, M.S.A. (2020). Attention, Awareness, and the Right Temporoparietal Junction


DATA & FILE OVERVIEW

1. File List: 
sub-105: Individual subject data folder containing anatomical, function, and fieldmap files
sub-112
sub-113
sub-115
sub-117
sub-119
sub-121
sub-122
sub-123
sub-124
sub-125
sub-130
sub-133
sub-136
sub-156
sub-157
sub-158
sub-159
sub-126
sub-127
sub-128
sub-131
sub-132
sub-138
sub-139
sub-142
sub-143
sub-144
sub-145
sub-147
sub-149
sub-150
sub-153
sub-154
sub-155
Experiment_Log.xlsx: Experiment log containing experimental condition, direction of statistical trend, gnder, handedness, and age for each participant. Missing number are due to a third experimental condition that is not included in this dataset
Behavioral: Folder containing behavioral data and relevent analysis scripts
Behavioral/Data: Behavioral task data for each participant (includes processed data, raw data, and timestamps for each event)
Behavioral/MRI_Run_Task.m: Script for starting the behavioral task
Behavioral/MRI_Train.m: Script containing the actual behavioral task
Attention_Awareness_Dorsal_Attention_README.txt: Readme file for this dataset


2. Relationship between files, if important: 
Important file structures are preserved by zipping.

3. Additional related data collected that was not included in the current data package: N/A

4. Are there multiple versions of the dataset? no


METHODOLOGICAL INFORMATION

1. Description of methods used for collection/generation of data: 
For an overview of the behavioral task design and logic, see: Wilterson, A. I., Kemper, C., Kim, N., Webb, T. W., Reblando, A. M. W., & Graziano, M. S. A. (2020). Attention Control and the Attention Schema Theory of Consciousness. In Progress in Neurobiology, in press. (available online)

Subjects were split into two key conditions: aware and unaware. Subjects in the unaware condition were exposed to a cue that was backwards masked, rendering it subliminal. Subjects in the aware condition received the same stimuli, except that the color of the cue was changed, rendering masking ineffective. Participants engaged in a target discrimination task in which the location of the target was probabilistically related to the location of the cue.

fMRI data were collected over 10 scans, during each of which participants completed 60 trials of the behavioral task. All major stimulus events are flagged in the behavioral data for analysis.

Anatomical images were collected prior to the behavioral task. Field maps were collected after completion of the behavioral task.

2. Methods for processing the data: 

All provided MRI images were preprocessed using the most recent version of fMRIprep available at the time, see: Esteban O, Markiewicz CJ, Blair RW, Moodie CA, Isik AI, Erramuzpe A, Kent JD, Goncalves M, DuPre E, Snyder M, Oya H, Ghosh SS, Wright J, Durnez J, Poldrack RA, Gorgolewski KJ. fMRIPrep: a robust preprocessing pipeline for functional MRI. Nat Meth. 2018; doi:10.1038/s41592-018-0235-4


3. Instrument- or software-specific information needed to interpret the data: 
Behavioral scripts require: MATLAB 2016 or later, Psychtoolbox 2016 or later


4. Standards and calibration information, if appropriate: N/A

5. Environmental/experimental conditions: Aware vs. Unaware (see answer 1, above)

6. Describe any quality-assurance procedures performed on the data: 
Data from subjects who were observed to be falling asleep are not included in this dataset.
All data were screened using fMRIprep's QC outputs. Subject data featuring frequent or high magnitude movement are not included in this dataset.

7. People involved with sample collection, processing, analysis and/or submission: 
Andrew I. Wilterson performed data collection and the bulk of the analysis. All authors cited above contributed to analysis, with special thanks to Sam Nastase.

DATA-SPECIFIC INFORMATION FOR: Behavioral/Data/SUBJECTNUMBER/Summary_SUBJECTNUMBER_TRAIN.mat

1. Number of variables: 17

2. Variable List: 
Condition: 1 for Aware Condition, 2 for Unaware Condition
Index: Gives the trial index for each event of each trial type (unit is trial number)
Vars: Gives the cue location (cState), target location relative to cue (tSide), cue validity (Validity), target state (tAngle), and imposed temporal jitter (jitter) for each trial.
Expected_RTs: Reaction time (in seconds) to each trial in which the target appeared in the more probable location relative to the cue
Unexpected_RTs: Reaction time (in seconds) to each trial in which the target appeared in the less probable location relative to the cue
Prev_Cong_RTs and Prev_Incong_RTs: Not relevant to the dataset, ignore.
Proportion_Correct: The fraction of the total trials that got a correct response
deltaAccuracy: The difference in accuracy between Expected and Unexpected target locations
Proportion_Correct_Expected: The fraction of Expected trials that got a correct response
Proportion_Correct_Unexpected: The fraction of Unexpected trials that got a correct response
deltaRT_ExpectedVsUnexpected: The difference in reaction time (in ms) between Expected and Unexpected trials. A positive value indicates that Expected trial responses were faster
deltaRT_PrevTrial: Not relevant, ignore
deltaRT_Window_Mat_ExpectedVsUnexpected: Measures deltaRT over 6 blocks of trials, for examining learning timecourses
deltaRT_Num_Windows: Number of blocks used in above metric (6)
deltaRT_Window_Mat_ExpectedVsUnexpected2: Measures deltaRT over 3 blocks of trials, for examining learning timecourses
deltaRT_Num_Windows2: Number of blocks used in above metric (3)
