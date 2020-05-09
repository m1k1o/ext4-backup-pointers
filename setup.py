from setuptools import setup

README = """
ext4-backup-pointers
====================
Please follow the information provided on GitHub here: https://github.com/m1k1o/ext4-backup-pointers
"""

setup(
    name='ext4-backup-pointers',
    version='0.1',
    description='EXT4 backup inode data pointers & recover selected files.',
    long_description=README,
    long_description_content_type='text/x-rst',
    url='https://github.com/m1k1o/ext4-backup-pointers',
    author='Miroslav Sedivy',
    author_email='sedivy.miro@gmail.com',
    license='Apache 2.0',
    keywords='ext4-filesystem file-recovery backup',
    packages=['src'],
    entry_points={
        'console_scripts': [
            'ext4-backup-pointers=src:console',
        ],
    },
)
