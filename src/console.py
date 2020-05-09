import argparse
import os

from src.utils import generate_snapshot, recover_file

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
        output_file=output_file
    )

"""
ext4-backup-pointers create -i data_fs.img [-o snapshot-2020-05-09.json]
ext4-backup-pointers recover -i data_fs.img -s snapshot-2020-05-09.json /some/file.jpg [-o file.jpg]
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
    parser_recover.set_defaults(func=recover)

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
