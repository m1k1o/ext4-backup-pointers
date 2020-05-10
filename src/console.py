import argparse
import textwrap
import os

from src.utils import generate_snapshot, recover_file, list_deleted

def create(args):
    # Default output
    if args.output is None:
        snapshot_file = os.path.basename(args.input) + '.snapshot.out'
    else:
        snapshot_file = args.output

    snapshot = generate_snapshot(
        fs=args.input,
        snapshot_file=snapshot_file,
        dirs_max_depth=args.dirs_max_depth
    )

def recover(args):
    # Default output
    if args.output is None:
        output_file = os.path.basename(args.file_path)
    else:
        output_file = args.output

    recover_file(
        fs=args.input,
        snapshot_file=args.snapshot,
        file_path=args.file_path,
        output_file=output_file,
        verify_checksum=not args.force
    )

def ls(args):
    deleted_files = list_deleted(
        fs=args.input,
        snapshot_file=args.snapshot
    )

    print("total {}".format(len(deleted_files)))
    for path, v in deleted_files.items():
        print("{:5}{:<13}{}".format(
            'OK' if v['can_be_recovered'] else 'ERR',
            v['size'],
            path
        ))

"""
ext4-backup-pointers create -i data_fs.img [-o snapshot-2020-05-09.json]
ext4-backup-pointers recover -i data_fs.img -s snapshot-2020-05-09.json /some/file.jpg [-o file.jpg]
ext4-backup-pointers ls -i data_fs.img -s snapshot-2020-05-09.json
"""
def start():
    # create the top-level parser
    parser = argparse.ArgumentParser(
        prog='ext4-backup-pointers',
        description='EXT4 backup inode data pointers & recover selected files'
    )
    #parser.add_argument('-d', '--debug', action='store_true', help='show debug output')
    subparsers = parser.add_subparsers()

    # create the parser for the "create" command
    parser_create = subparsers.add_parser('create', help='create metadata snapshot')
    parser_create.add_argument('-i', '--input', type=str, help='image of file system', required=True)
    parser_create.add_argument('-o', '--output', type=str, help='metadata snapshot output file', required=False)
    parser_create.add_argument('-depth', '--dirs-max-depth', type=int, help='maximum depth of directory traversal', required=False, default=100)
    parser_create.set_defaults(func=create) 

    # create the parser for the "recover" command
    parser_recover = subparsers.add_parser('recover', help='recover file from metadata snapshot')
    parser_recover.add_argument('-i', '--input', type=str, help='image of file system', required=True)
    parser_recover.add_argument('-s', '--snapshot', type=str, help='metadata snapshot generated using "create"', required=True)
    parser_recover.add_argument('file_path', type=str, help='absolute path of wanted file inside of supplied file system')
    parser_recover.add_argument('-o', '--output', type=str, help='output file, where will be recovered file saved', required=False)
    parser_recover.add_argument('-f', '--force', action='store_true', help='recover even if data blocks of file have been already allocated and file might be corrupted', required=False)
    parser_recover.set_defaults(func=recover)

    parser_ls = subparsers.add_parser('ls',
        help='list all deleted files, that are present in snapshot',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        description=textwrap.dedent('''\
            columns:
              1. OK  - file can be recovered.
                 ERR - data blocks of file have already been allocated.
              2. Filesize in bytes.
              3. Absolute file path.
        ''')
    )
    parser_ls.add_argument('-i', '--input', type=str, help='image of file system', required=True)
    parser_ls.add_argument('-s', '--snapshot', type=str, help='metadata snapshot generated using "create"', required=True)
    parser_ls.set_defaults(func=ls)

    # parse argument lists
    args = parser.parse_args()

    # run function
    try:
    	args.func(args)
    except AttributeError:
        parser.print_help()
        parser.exit()
    except Exception as e:
        print("*** ERROR! ***")
        print(e)
