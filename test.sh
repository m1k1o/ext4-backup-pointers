#!/bin/bash
cd "$(dirname "$0")"

#
# INSTALL SW
#

python setup.py install

#
# SETUP FS
#

dd if=/dev/zero of=data_fs.img bs=1M count=250
mkfs.ext4 data_fs.img

# Create block device (/dev/loop0).
# losetup -a
LOOP="$(losetup -fP --show data_fs.img)"

mkdir data_fs
mount "$LOOP" data_fs
cd data_fs

#
# CREATE TEST FILES
#

# add 15 random files
i="0"
while [ $i -lt 15 ]; do
	dd if=/dev/zero of="pad_file_$i" bs=1M count=10
	i=$[$i+1]
done

# remove every second file
i="0"
while [ $i -lt 15 ]; do
	rm "pad_file_$i"
	i=$[$i+2]
done

# add big file
mkdir -p test/dir
dd if=/dev/urandom of=test/dir/tested_file bs=1M count=70

# sync fs
sync

cd ..

#
# CREATE SNAPSHOT
#

ext4-backup-pointers create -i data_fs.img -o snapshot.out

#
# REMOVE FILE 
#

# save md5
md5_to_test=$(md5sum "data_fs/test/dir/tested_file" | cut -d " " -f1)

# remove
rm data_fs/test/dir/tested_file

# sync fs
sync

#
# RESTORE FILE
#

ext4-backup-pointers recover -i data_fs.img -s snapshot.out /test/dir/tested_file -o recovered_file

#
# VERIFY FILE
#

md5_from_file=$(md5sum "recovered_file" | cut -d " " -f1)
md5_results="Original:  $md5_to_test\nRecovered: $md5_from_file"
if [[ $md5_to_test == $md5_from_file ]]
then
	echo -e "\n\e[92mSUCCESS\e[39m\n$md5_results"
else
	echo -e "\n\e[91mFAILURE\e[39m\n$md5_results"
fi

#
# CLEAN UP
#

umount data_fs
rmdir data_fs

# detach loop device
losetup -d /dev/loop1

# remove fs image & others
rm -f data_fs.img snapshot.out recovered_file
