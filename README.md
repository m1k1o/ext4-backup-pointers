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
* At restoration it checks data block of recovered file against current data block bitmap to see whether file can be restored successfully. If those data blocks have been already allocated, they have been most likely overwritten, and integrity of restored file cannot be guaranteed. This check is optional.

## What does it **NOT** do?
* This software is not intended to backup whole filesystems metadata and restore it, but only to get one file from before created backup.
* This software cannot recover deleted file if metadata snapshot of filesystem was not created before deletion, and intended file is not in backup snapshot.
* This software cannot recover files deleted using any other software, that ensures all data blocks are cleared.
* This software cannot recover any other filetype than **S_IFREG (Regular file)** e.g. symlinks.

## How does it work?
First step is to create snapshot, then recover file from this snapshot.

### Creating snapshot
It reads plain filesystem image and gets all used inodes. Then it attempts to gain all data blocks addressed by inode, as if it were trying to read that file. All those pointers along with *inode id* and *file size* are being saved. It traverses whole directory structure from root until given depth and saves absolute file addresses along with *inode id*. Both structures are considered as snapshots.

### Recovering file
In snapshot it finds corresponding *inode id* and then saved data fragments with file size. It reads all fragments from original filesystem to new file. If checksum is active, it checks whether file has been removed an whether its data blocks have not been allocated by filesystem.

## Install
You can install this module and use it as command line tool.
```
python setup.py install
```

And then use it like this:
```
$ ext4-backup-pointers
usage: ext4-backup-pointers [-h] {create,recover,ls} ...

EXT4 backup inode data pointers & recover selected files

positional arguments:
  {create,recover,ls}
    create             create metadata snapshot
    recover            recover file from metadata snapshot
    ls                 list all deleted files, that are present in snapshot

optional arguments:
  -h, --help           show this help message and exit
```

## Example
**Create snapshot.** It creates snapshot of filesystem image `data_fs.img` and saves to `data_fs.img.snapshot.out` (if not otherwise specified, using `-o`).

```
$ ext4-backup-pointers create -i data_fs.img
```

**Recover file** from filesystem image and snapshot. Absolute path to recovered file inside given filesystem is `/my_file.jpg`. It stores recovered file to current directory with same base name as recovered file.
```
$ ext4-backup-pointers recover -i data_fs.img -s data_fs.img.snapshot.out /my_file.jpg
```

**List files**, that have been deleted in given filesystem but are present in snapshot. Each entry consists of:
  1. *OK* - file can be recovered.
     *ERR* - data blocks of file have already been allocated.
  2. Filesize in bytes.
  3. Absolute file path
```
$ ext4-backup-pointers ls -i data_fs.img -s data_fs.img.snapshot.out
total 1
OK   1558173      /my_file.jpg
```

### Source code
Example of code usage can be found in Jupyter Notebook file `example.ipynb`.

```python
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
	output_file="my_file.jpg",    # File, where will be recovered data written
	verify_checksum=True          # Check, whether all file blocks have not been allocated by fs
)
list_deleted(
	fs="data_fs.img",             # Filesystem image file
	snapshot_file="snapshot.out"  # Snapshot metadata file path
)
```

### Testing
For testing please see file `test.sh`. EXT- filesystems are backwards complatible, so this program will work in EXT2/3 filesystem as well. This can be tested using automatic testing tool, that will create custom file system and populate it with testing files.

```
-- use it like this --

./test.sh setup [ext4]   # setup test filesystem. (run as root)
                         # - optional: (ext2, ext3, ext4)
./test.sh run            # run rests.
./test.sh clear          # clear test filesystem. (run as root)
./test.sh full [ext4]    # create & test & clear. (run as root)
                         # - optional: (ext2, ext3, ext4)

-- or run test steps individualy --

./test.sh install        # python install src.
./test.sh create_file    # create test file.
./test.sh snapshot       # create snapshot.
./test.sh remove_file    # remove test file.
./test.sh restore        # restore removed file from snapshot.
```

## Requirements

* python 3.7.6
* `dumpe2fs`, part of the **e2fsprogs** package and is available from http://e2fsprogs.sourceforge.net.
