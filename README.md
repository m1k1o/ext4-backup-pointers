**DISCLAIMER**: THIS SOFTWARE IS HIGHLY EXPERIMENTAL AND IF YOU ARE TRYING TO RECOVER LOST FILES YOU SHOULD USE ANOTHER SOFTWARE OTHERWISE YOUR DATA ARE AT RISK OF BEING LOST.

# ext4-backup-pointers
EXT4 backup inode data pointers & recover selected files.

## Motivation
After file deletion in EXT4 filesystem, it only discards metadata about that file. Real blocks containing file are not touched. Until they are not overwritten, there is chance to recover that file if one only had metadata.

Similar programs, that were found, did not allow user to just pickup and recover one file, instead they try to recover whole filesystem (e.g. `e2image -I`).
Sometimes you only want to restore one file, not restore all filesystem metadata what can lead to unintended failures. This program is not touching filesystem, only using it as read-only, so it should not cause any disruption.

## What does it do?
* This software creates snapshot of filesystem, containing only physical addresses of file fragments along with absolute path of file.
* Using its path, file can be recovered using saved metadata snapshot. Even if it was deleted in original filesystem.

## What does it **NOT** do?
* This software is not intended to backup whole filesystems metadata and restore it, but only to get one file from before created backup.
* This software cannot recover deleted file if metadata snapshot of filesystem was not created before deletion, and intended file is not in backup snapshot.
* This software cannot recover files deleted using any other software, that ensures all data blocks are cleared.
* This software cannot recover any other filetype than **S_IFREG (Regular file)** e.g. symlinks.
* File restoration can fail, if data blocks used by previously file have been allocated to another file. In this version, there is in fact no way of knowing, whether file was restored successfully, or some blocks have been overwritten. In following versions there might be implemented checksum mechanism.

## How does it work?
First step is to create snapshot, then recover file from this snapshot.

### Creating snapshot
It reads plain filesystem image and gets all used inodes. Then it attempts to gain all data blocks addressed by inode, as if it were trying to read that file. All those pointers along with *inode id* and *file size* are being saved. It traverses whole directory structure from root until given depth and saves absolute file addresses along with *inode id*. Both structures are considered as snapshots.

### Recovering file
In snapshot it finds corresponding *inode id* and then saved data fragments with file size. It reads all fragments from original filesystem to new file.

## Example
Example can be found in Jupyter Notebook file `example.ipynb`.

```
from src.utils import generate_snapshot, recover_file
generate_snapshot(
	fs="data_fs.img",             # Filesystem image file
	snapshot_file="snapshot.out", # Path, where will be snapshot metadata file created
	dirs_max_depth=100            # Max directory traversal depth
)
recover_file(
	fs="data_fs.img",             # Filesystem image file
	snapshot_file="snapshot.out", # Snapshot metadata file path generated from previous function
	file_path="/my_file.jpg",     # File to be recovered, absolute path
	output_file="my_file.jpg"     # File, where will be recovered data written
)
```

## Requirements

* python 3.7.6
* `dumpe2fs`, part of the **e2fsprogs** package and is available from http://e2fsprogs.sourceforge.net.
