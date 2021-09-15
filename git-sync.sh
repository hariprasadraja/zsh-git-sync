#!/bin/sh

_log() {
  util log info "$*"
}

_err() {
  util log error "$*"
}

_prefixed() {
  sed -e "s/^/       /"
}

_prune() {
  # shellcheck disable=SC2039
  local remote
  remote="$1"
  _log "Pruning $remote..."
  git remote prune "$remote" | _prefixed
}

_update() {
  # shellcheck disable=SC2039
  local remote
  remote="$1"
  _log "Updating $remote..."
  git fetch "$remote" | _prefixed
  git fetch -t "$remote" | _prefixed
}

_merge_locally() {
  # shellcheck disable=SC2039
  local branch remote
  remote="$1"
  branch="$2"
  _log "Merging $remote/$branch locally..."
  git merge --no-edit --summary --progress "$remote/$branch" | _prefixed
  if [[ $? != 0 ]]; then
    git merge --abort
  fi
}

_push_to_fork() {
  # shellcheck disable=SC2039
  local branch remote
  remote="$1"
  branch="$2"
  _log "Pushing it to $remote/$branch..."
  git push -u -v "$remote" "$branch" | _prefixed
  git push --tags -v "$remote" "$branch" | _prefixed
}

git-delete-local-merged() {
  # shellcheck disable=SC2039

  main_branch=$(basename "$(git symbolic-ref --short refs/remotes/origin/HEAD)")
  local branches
  _log "Removing merged branches..."
  branches="$(git branch --merged | grep -v "^\*" | grep -v "$main_branch" | tr -d '\n')"
  [ -n "$branches" ] && echo "$branches" | xargs git branch -d

  _log "Removing squashed and merged branches..."
  git for-each-ref refs/heads/ "--format=%(refname:short)" | while read -r branch; do
    base="$(git merge-base "$main_branch" "$branch")"
    hash="$(git rev-parse "$branch^{tree}")"
    commit="$(git commit-tree "$hash" -p "$base" -m _)"
    [[ $(git cherry "$main_branch" "$commit") == "-"* ]] && git branch -D "$branch"
  done
}

git-require_clean_work_tree () {
    # Update the index
    git update-index -q --ignore-submodules --refresh
    err=0

    # Disallow unstaged changes in the working tree
    if ! git diff-files --quiet --ignore-submodules --
    then
        _err "cannot $1: you have unstaged changes."
        git diff-files --name-status -r --ignore-submodules -- >&2
        err=1
    fi

    # Disallow uncommitted changes in the index
    if ! git diff-index --cached --quiet HEAD --ignore-submodules --
    then
        _err "cannot $1: your index contains uncommitted changes."
        git diff-index --cached --name-status -r --ignore-submodules HEAD -- >&2
        err=1
    fi

    if [ $err = 1 ]
    then
        _err "Please commit or stash them."
        exit 1
    fi
}

# shellcheck disable=SC2039
git-sync() {
  git-require_clean_work_tree
  currentBranch=$(git branch --show-current)
  local remotes=()
  for branch in $(git for-each-ref --format='%(refname:lstrip=2)' refs/heads/); do
    # check if upstream branch exist or not
    if ! remote_branch="$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null)"; then
      _log "There is no upstream information of local branch. skipping Sync"
      continue
    fi

    local remote=$(git config "branch.${branch}.remote")
    exists=false
    for item in ${remotes[@]}; do
      if [ "$item" == "$remote" ]; then
        exists=true
      fi
    done

    if [ $exists == false ]; then
      _log "New Remote: $remote"
      _prune "$remote"
      _update "$remote"
      remotes+=($remote)
    fi

    _log "Synchronizing $branch to $remote/$branch..."
    git switch $branch

    local head remotehead base

    # @ - Head commit
    # @{u} - Head commit on the remote branch
    # LOCAL points to the most recent commit made on the local branch
    head=$(git rev-parse @)
    # Remote points to the most recent commit made on the Remote branch
    remotehead=$(git rev-parse @{u})
    # common parrent commit for both the references
    base=$(git merge-base @ @{u})

    if [ $head = $remotehead ]; then
      # Local and the Remote References are Identical
      _log "Already Updated"
      continue
    fi

    if [ $head = $base ]; then
      # Got New References from Remote
      _merge_locally "$remote" "$branch"
    fi

    if [ $remotehead = $base ]; then
      _push_to_fork "$remote" "$branch"
    else
      _log "Conflict: $remote/branch is diverged. Skiping merge. Resolve it ASAP!"
      continue
    fi

  done

  git switch $currentBranch
  git-delete-local-merged
  _log "All done!"
}
