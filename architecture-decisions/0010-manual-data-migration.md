# Manual Data Migration

## Status

Discussion

## Context

Some DataSpace objects cannot be automatically migrated. As of June 2023 this includes works whose attachments in DataSpace are so substantial that the network connection used by the automated migration process times out. Because we believe the number of these items will be small, the team decided not to optimize the code to handle this rarely encountered use case. Instead, we will migrate the object by hand. This mimics the practices in place at PUL for several years before the DataSpace --> PDC Describe migration started, where very large data deposits in DataSpace were transferred to Globus manually. This will also be the process to follow for any items that give a "Checksums do not match" error during migration. Thus far in our testing, checksums fail to match when the network connection times out and the download doesn't complete correctly via the automated migration process. 



Some objects will be migrated via a slightly different process. However, this process is one that was already in use at PUL and now it is better documented. While time consuming, and thus not our preferred system, we have no evidence that this manual migration process will compromise the integrity of the data. 