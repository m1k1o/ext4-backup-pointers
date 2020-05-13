#!/bin/bash
cd "$(dirname "$0")"

# load state - loop device
if [ -f "loop.txt.test" ]; then
	LOOP="$(cat loop.txt.test)"
fi

# load state - original md5
if [ -f "md5.txt.test" ]; then
	MD5_ORIGINAL="$(cat md5.txt.test)"
fi

# check whether last command was successful
CATCH() {
	if ! [ $? -eq 0 ]
	then
		exit
	fi

	echo $1
}

#
# INSTALL SW
#
install() {
	python3 setup.py install
}

#
# FILESYSTEM CREATE
#
fs_create() {
	dd if=/dev/zero of=data_fs.img.test bs=1M count=250
	CATCH "[OK] Created empty file."

	mkfs.ext4 data_fs.img.test
	CATCH "[OK] Created ext4 filesystem."
}

#
# FILESYSTEM UP
#
fs_up() {
	if [ "$EUID" -ne 0 ]
	then
		echo "Please run as root"
		exit
	fi

	# Create block device (/dev/loop0).
	# losetup -a
	LOOP="$(losetup -fP --show data_fs.img.test)"
	CATCH "[OK] Created block device: $LOOP"

	mkdir data_fs
	CATCH "[OK] Created directory data_fs."

	mount "$LOOP" data_fs
	CATCH "[OK] Mounted $LOOP to data_fs."

	chmod -R 777 data_fs data_fs.img.test

	# save state
	echo "$LOOP" > "loop.txt.test"
}

#
# FILESYSTEM DOWN
#
fs_down() {
	if [ "$EUID" -ne 0 ]
	then
		echo "Please run as root"
		exit
	fi

	umount data_fs
	CATCH "[OK] Umounted data_fs."

	rmdir data_fs
	CATCH "[OK] Removed directory data_fs."

	# detach loop device
	losetup -d "$LOOP"
	CATCH "[OK] Detached block device."

	# remove fs image & snapshot
	rm -f data_fs.img.test
	CATCH "[OK] Removed filesystem image."

	# clear state
	rm loop.txt.test md5.txt.test
}

#
# CREATE TEST FILE
#
create_file() {
	# remove pad files if existed
	rm data_fs/pad_file_*
	rm -r data_fs/test

	# add 15 random files
	i="0"
	while [ $i -lt 15 ]; do
		dd if=/dev/zero of="data_fs/pad_file_$i" bs=1M count=10
		CATCH "[OK] Created file: pad_file_$i"
		i=$[$i+1]
	done

	# remove every second file
	i="0"
	while [ $i -lt 15 ]; do
		rm "data_fs/pad_file_$i"
		CATCH "[OK] Removed file: pad_file_$i"
		i=$[$i+2]
	done

	# add big file
	mkdir -p data_fs/test/dir
	CATCH "[OK] Created test direcotry."

	dd if=/dev/urandom of=data_fs/test/dir/tested_file bs=1M count=70
	CATCH "[OK] Created test file with random data."

	# save md5
	MD5_ORIGINAL=$(md5sum "data_fs/test/dir/tested_file" | cut -d " " -f1)
	CATCH "[OK] Computed MD5 of test file: $MD5_ORIGINAL"

	# sync fs
	sync -f data_fs
	CATCH "[OK]  Synced."

	# save state
	CATCH "$MD5_ORIGINAL" > "md5.txt.test"
}

#
# REMOVE TEST FILE 
#
remove_file() {
	# remove
	rm -r data_fs/test
	CATCH "[OK] Recursively removed test folder."

	# sync fs
	sync -f data_fs
	CATCH "[OK]  Synced."
}

#
# CREATE SNAPSHOT
#
snapshot() {
	ext4-backup-pointers create -i data_fs.img.test -o snapshot.out.test
	CATCH "[OK] Created snapshot."
}

#
# RESTORE FILE
#
restore() {
	ext4-backup-pointers recover -i data_fs.img.test -s snapshot.out.test /test/dir/tested_file -o recovered_file
	CATCH "[OK] Recovered test file."

	MD5_RECOVERED=$(md5sum "recovered_file" | cut -d " " -f1)
	response="Original:  $MD5_ORIGINAL\nRecovered: $MD5_RECOVERED"
	if [[ $MD5_ORIGINAL == $MD5_RECOVERED ]]
	then
		echo -e "\n\e[92mSUCCESS\e[39m\n$response"
	else
		echo -e "\n\e[91mFAILURE\e[39m\n$response"
	fi

	# remove fs image & others
	rm -f recovered_file
}

case $1 in
	install) install;;
	create_file) create_file;;
	remove_file) remove_file;;
	snapshot) snapshot;;
	restore) restore;;

	full)
		install
		if ! [ -f "loop.txt.test" ]; then
			fs_create
			fs_up
		elif ! losetup "$LOOP"; then
			echo "Filesystem is already created, mountig..."
			fs_up
		fi
		create_file
		snapshot
		remove_file
		restore
		fs_down
		;;

	run)
		if ! [ -f "loop.txt.test" ]; then
			echo "Filesystem must be created first..."
			exit
		elif ! losetup "$LOOP"; then
			echo "Filesystem is created, but loop device is not up..."
			exit
		fi
		install
		create_file
		snapshot
		remove_file
		restore
		;;

	setup)
		if ! [ -f "loop.txt.test" ]; then
			fs_create
			fs_up
		elif ! losetup "$LOOP"; then
			echo "Filesystem is already created, mountig..."
			fs_up
		else
			echo "Filesystem is already created and mounted..."
		fi
		;;

	clear)
		if [ -f "loop.txt.test" ]; then
			fs_down
		else
			echo "Nothing to clear..."
		fi
		;;

	*)
		echo '-- use it like this --'
		echo ''
		echo './test.sh setup          # setup test filesystem. (run as root)'
		echo './test.sh run            # run rests.'
		echo './test.sh clear          # clear test filesystem. (run as root)'
		echo './test.sh full           # create & test & clear. (run as root)'
		echo ''
		echo '-- or run test steps individualy --'
		echo ''
		echo './test.sh install        # python install src.'
		echo './test.sh create_file    # create test file.'
		echo './test.sh snapshot       # create snapshot.'
		echo './test.sh remove_file    # remove test file.'
		echo './test.sh restore        # restore removed file from snapshot.'
		echo ''
		;;
esac
