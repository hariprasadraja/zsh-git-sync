#!/bin/sh

function _usage() {
  local command="git sync"
  cat <<EOS
Usage:
  ${command} [<remote> <branch>]
  ${command} -h | --help
  ${command} -s | --soft
Sync local branch with <remote>/<branch>.
When <remote> and <branch> are not specified on the command line, upstream of local branch will be used by default.
All changes and untracked files and directories will be removed unless you add -s(--soft).
Examples:
  Sync with upstream of local branch:
    ${command}
  Sync with origin/master:
    ${command} origin master
  Sync without cleaning untracked files:
    ${command} -s
EOS
}

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
  _log "Pruning $remote..."
  git fetch --all "$remote" | _prefixed
  git fetch -t "$remote" | _prefixed
}

_merge_locally() {
  # shellcheck disable=SC2039
  local branch remote
  remote="$1"
  branch="$2"
  _log "Merging $remote/$branch locally..."
  git stash
  git merge --no-edit --rebase "$remote/$branch" | _prefixed
  git stash pop
}

_push_to_fork() {
  # shellcheck disable=SC2039
  local branch remote
  remote="$1"
  branch="$2"
  if ! [ "$remote" = "origin" ]; then
    _log "Pushing it to origin/$branch..."
    git push origin "$branch" | _prefixed
  fi
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
  while [ "$1" != "" ]; do
    case $1 in
    -h | --help)
      _usage
      exit
      ;;
    -s | --soft)
      local soft="true"
      ;;
    *)
      if [ "${remote}" = "" ]; then
        local remote="$1"
      elif [ "${branch}" = "" ]; then
        local branch="$1"
      else
        echo -e "Error: too many arguments.\n"
        _usage
        exit 1
      fi
      ;;
    esac
    shift
  done

  if [ "${remote}" = "" ]; then
    if ! remote_branch="$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null)"; then
      echo "There is no upstream information of local branch."
      exit 1
    fi
    local branch="$(git rev-parse --abbrev-ref --symbolic-full-name @)"
    local remote=$(git config "branch.${branch}.remote")
  elif [ "${branch}" = "" ]; then
    echo -e "Error: too few arguments.\n"
    _usage
    exit 1
  fi

  # shellcheck disable=SC2039
  _prune "$remote"
  _update "$remote"

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
  elif [ $LOCAL = $BASE ]; then
    # Got New References from Remote
    _log "Need to Merge"

    # check if upstream branch exist or not
    if ! remote_branch="$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null)"; then
      _log "There is no upstream information of local branch. skipping Merge"
      exit 1
    fi

    _merge_locally "$remote" "$branch"
    _push_to_fork "$remote" "$branch"

  elif [ $REMOTE = $BASE ]; then
    _log "found new commits in local branch"
    _push_to_fork "$remote" "$branch"
  else
    _log "Conflict: branch is diverged. fix it ASAP!"
    exit 1
  fi

  git branch -u "$remote/$branch"
  git-delete-local-merged
  _log "All done!"
}
