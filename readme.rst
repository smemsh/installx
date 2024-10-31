installx
==============================================================================

**installx, installrc**

Populates binfiles in ``~/bin/`` and dotfile symlinks like ``~/.foorc ->
src/dotfiles/foo.conf``, from git checkouts.

Installs from dir ``<cwd>`` (or $1) all executable files and symlinks
(``installx``), or all .rclinks (``installrc``), to ``<homedir>`` (or $2).

:installx:
  cp exefiles, and symlinks to in-dir exes, from ${1:-.}/ to ${2:-~/bin}/

:installrc:
  recreate using relative links in ${2:-~}/, all .rclinks in ${1:-.}/ which
  target files in {$1:-.}/, including any intermediate links (with needed
  mkdirs) in chains of multi-level symlinks, as long as all levels are
  descendants of ${1:-.}/ and the end target is in ${1:-.}/

This is currently used to manifest the changes pulled in bin/dotfile
repositories deployed with a `git clone` and kept updated by using
https://github.com/smemsh/git-reltag/, but the latter tool is not
required.

| scott@smemsh.net
| https://github.com/smemsh/installx/
| https://spdx.org/licenses/GPL-2.0
