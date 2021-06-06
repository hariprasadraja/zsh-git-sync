# git-sync [![Build Status](https://travis-ci.org/caarlos0/zsh-git-sync.svg?branch=master)](https://travis-ci.org/caarlos0/zsh-git-sync)

Sync git repositories and clean them up.

Modified version of [git-extras/git-sync](https://github.com/tj/git-extras/blob/master/bin/git-sync)

```sh
❯ git sync
-----> Pruning origin...
-----> Updating origin...
-----> found new commits in local branch
-----> Pushing it to origin/master...
Enumerating objects: 5, done.
Counting objects: 100% (5/5), done.
Delta compression using up to 2 threads
Compressing objects: 100% (3/3), done.
Writing objects: 100% (3/3), 306 bytes | 306.00 KiB/s, done.
Total 3 (delta 2), reused 0 (delta 0)
remote: Resolving deltas: 100% (2/2), completed with 2 local objects.
To github.com:hariprasadraja/zsh-git-sync.git
   57960c0..11a12a5  master -> master
Branch 'master' set up to track remote branch 'master' from 'origin'.
-----> Removing merged branches...
-----> Removing squashed and merged branches...
-----> All done!
```

## Define `sync`

- prune `origin` or `upstream`;
- merge `upstream` into current branch;
- push merged branch to fork (`origin`);
- remove merged branches.

## Install

```console
$ antibody bundle 'caarlos0/zsh-git-sync kind:path'
```

Or use `antigen` to load it as a shell plugin.

## Usage

If you used antibody, the folder will be cloned and added to your `$PATH`,
so, calling `git sync` will just work out of the box.


Otherwise, you'll need to add it to your git config:

```console
$ git config --global alias.sync '!zsh -ic git-sync'
```

There is also `git delete-local-merged`, which only deletes
locally merged branches (part of the cleanup thing).

Again, with antibody, `git delete-local-merged` will just work, otherwise:

Example:

```console
$ git config --global alias.delete-local-merged '!zsh -ic git-delete-local-merged'
```
