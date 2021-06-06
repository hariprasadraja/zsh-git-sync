#!/bin/sh

_log() {
  echo "-----> $*"
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
  git stash
  git merge --no-edit --summary --progress "$remote/$branch" | _prefixed
  git stash pop
}

_push_to_fork() {
  # shellcheck disable=SC2039
  local branch remote
  remote="$1"
  branch="$2"
  _log "Pushing it to $remote/$branch..."
  git push "$remote" "$branch" | _prefixed
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

# shellcheck disable=SC2039
git-sync() {
  currentBranch=$(git branch --show-current)
  for branch in $(git for-each-ref --format='%(refname:lstrip=2)' refs/heads/); do
    # check if upstream branch exist or not
    if ! remote_branch="$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null)"; then
      _log "There is no upstream information of local branch. skipping Sync"
      continue
    fi

    local remote=$(git config "branch.${branch}.remote")
    _prune "$remote"
    _update "$remote"

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

    elif [ $head = $base ]; then
      # Got New References from Remote
      _merge_locally "$remote" "$branch"
    fi

    if [ $remotehead = $base ]; then
      _push_to_fork "$remote" "$branch"
      git branch -u "$remote/$branch"
    else
      _log "Conflict: branch is diverged. fix it ASAP!"
      continue
    fi

  done

  git switch $currentBranch
  git-delete-local-merged
  _log "All done!"
}
