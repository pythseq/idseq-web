#!/bin/bash
set -euo pipefail
SCRIPT_DIR=$(dirname "$0")
source "$SCRIPT_DIR/_global_vars.sh"
source "$SCRIPT_DIR/_shared_functions.sh"

__help() {
cat <<EOS
Deploys the docker image related to a git rev.

Usage: $0 [Optional arguments] <env> <rev>

  Positional arguments:
      env      Environment to deploy (ex: staging, prod, sandbox)
      rev      any git rev following these conventions:
               https://git-scm.com/docs/git-rev-parse#_specifying_revisions
               (ex: /origin/prod, v_0.21_prod, d13a89da)

  Optional arguments:
      --skip-ecr-check        Skip the check that ensures the docker image is already in ECR
      --skip-github-check     Skip the check that ensures all github checks passed for that commit
      --help                  This help file
EOS
}

__params() {
  declare flag_skip_ecr_check=
  declare flag_skip_github_check=
  while getopts ab: name
  do
      case $name in
      skip-ecr-check)    flag_skip_ecr_check=1;;
      skip-github-check) flag_skip_github_check=1;;
      ?)   printf "Banana %s\n" $0
            exit 2;;
      esac
  done
  shift $(($OPTIND - 1))
  printf "Remaining arguments are: %s\n$*"
  echo flag_skip_ecr_check=$flag_skip_ecr_check
  echo flag_skip_github_check=$flag_skip_github_check
}

main() {
  declare env="$1" # staging / prod
  declare git_rev="$2" # https://git-scm.com/docs/git-rev-parse#_specifying_revisions
  _git_fetch_and_cleanup

  declare sha; sha=$(git log -n1 "${git_rev}" --format=%h --abbrev=8)
  declare docker_image="${ECR_REPOSITORY_NAME}:sha-$sha"

  _log "Starting deployment of $git_rev (sha-$sha) to $env"

  _log "Checking if docker image $docker_image is available"
  if ! __retry 15 60 __docker_tag_exists "${ECR_REPOSITORY_NAME}" "sha-$sha"; then
    _exit_with_err_msg "Couldn't find image ${docker_image} in docker hub"
  fi

  _log "Checking if Github commit ${sha} in a valid state"
  if ! __retry 15 60 __check_commit_state "${sha}" "$env"; then
    _exit_with_err_msg "Commit ${sha} is in an invalid state. Aborting deployment. More details at $GITHUB_REPOSITORY_URL/commits/${env}"
  fi

  echo "$SCRIPT_DIR/../deploy" "$env" "sha-$sha"
}

__docker_tag_exists() {
  declare repository_name="$1"
  declare tag="$2"
  aws ecr describe-images --repository-name "$repository_name" --image-ids imageTag="$tag" | jq -e
}

__check_commit_state() {
  declare sha="$1"
  declare branch="$2"

  declare response_json; response_json=$(
    http --ignore-stdin --timeout 30 --check-status -b \
      GET "$GITHUB_REPOSITORY_API/commits/$sha/status"
  )

  declare state; state="$(jq -er .state <<< "$response_json")"
  if [ "$state" != "success" ]; then
    _trace "Invalid state '$state' for commit ${sha} in branch ${branch}. More details at $GITHUB_REPOSITORY_URL/commits/${branch}"
    return 1
  fi
}

__retry() {
  declare attempts="$1"
  declare sleep_seconds="${2}"
  declare cmd="${*:3}"

  declare n=0
  declare exit_code
  until [[ $n -ge $attempts ]]; do
    { $cmd && exit_code=0 && break; } || {
      exit_code=$?
      ((n++))
      _trace "Command failed with exit code $exit_code. Waiting ${sleep_seconds} seconds before next attempt ($n of $attempts)"
      sleep "$sleep_seconds";
    }
  done
  return $exit_code
}

# main "$@"
__params
