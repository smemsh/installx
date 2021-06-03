#!/usr/bin/env python3
"""
installs in-dir exe files and symlinks, or all .rclinks, to [homedir]

  installx: cp exefiles and symlinks to in-dir exes: ${1:-./} -> ${2:-~/bin/}
  installrc: cp .rclinks as: ${1:-.}/.rclink -> ${2:-~/${PWD##*/}}/target

"""
__url__     = 'http://smemsh.net/src/utilpy/'
__author__  = 'Scott Mcdermott <scott@smemsh.net>'
__license__ = 'GPL-2.0'

###

import argparse

from sys import argv, stderr, exit
from os import environ

from os import EX_OK as EXIT_SUCCESS
from os import EX_SOFTWARE as EXIT_FAILURE

#

args = None

#

def err(*args, **kwargs):
    print(*args, file=stderr, **kwargs)

def bomb(*args):
    err(*args)
    exit(EXIT_FAILURE)

###

def process_args():

    def addflag(parser, flagchar, longopt):
        options = list(("-%s --%s" % (flagchar, longopt)).split())
        parser.add_argument(*options, action='store_true')

    def addarg(parser, varname, vardesc):
        parser.add_argument(varname, nargs=1, metavar=vardesc)

    p = argparse.ArgumentParser(
        prog            = invname,
        description     = __doc__.strip(),
        allow_abbrev    = False,
        formatter_class = argparse.RawTextHelpFormatter,
    )
    addflag (p, 'n', 'test')
    addflag (p, 'q', 'quiet')
    addflag (p, 'f', 'force')
    addarg  (p, 'src', 'srcdir')
    addarg  (p, 'dest', 'destdir')

    return p.parse_args(args)


def main():

    args = process_args()
    print(args)


if (__name__ == "__main__"):

    invname = argv[0]
    args = argv[1:]
    nargs = len(args)

    try:
        if (bool(environ['DEBUG'])):
            debug = True
            breakpoint()
            err('debug-mode-enabled')
        else:
            raise KeyError

    except KeyError:
        debug = False

    main()