#!/usr/bin/bash

function getReposQuery() {
    cat << EOQ
{
  viewer {
    repositories(first: 100) {
      edges {
        node {
          id
          nameWithOwner
          owner {
            url
          }
          defaultBranchRef {
            name
          }
          refs(first: 100, refPrefix: "refs/heads/") {
            pageInfo {
              endCursor
              hasNextPage
            }
            edges {
              cursor
              node {
                name
                target {
                 oid
                }
              }
            }
          }
        }
      }
    }
  }
}
EOQ
}

function nextRefsQuery() {
    local lastId="${1:?}"
    local lastRef="${2:-''}"

    cat << EOQ
query {
  node(id: "$lastId") {
    ... on Repository {
      id
      refs(first: 100, after: "$lastRef", refPrefix: "refs/heads/") {
        pageInfo {
          endCursor
          hasNextPage
        }
        edges {
          cursor
          node {
            name
            target {
              oid
            }
          }
        }
      }
    }
  }
}
EOQ
}


function getRepos() {
    gh api graphql -f query="$(getReposQuery)" -q '.data.viewer.repositories'
}

function nextRefs() {
    local lastId="${1:?}"
    local lastRef="${2:-''}"
    gh api graphql -f query="$(nextRefsQuery "$lastId" "$lastRef")" -q '.data.node'
}



function getRefs() {
    local -r arrayname="${1:?}"
    local -r json="${2:?}"

    local -i i
    local ref
    for ((i=0; i<"$(jq "length" <<< "$json")"; i++));do
        ref="$(jq -rc ".[$i]" <<< "$json")"
        name="$(jq -r '.node.name' <<< "$ref")"
        commit="$(jq -r '.node.target.oid' <<< "$ref")"
        printf '%s[%s]="%s" ' "$arrayname" "$name" "$commit"
    done
}

declare OWNER=ballab1

function main() {

    local -r JSON="${1:?}"

    local -i i count=0 ocnt=0
    local -A refs
    local json repo defaultBranch name defaultHead name commit id lastRef

    for ((i=0; i<"$(jq ".edges|length" <<< "$JSON")"; i++));do
#    for ((i=0; i<16; i++));do
      json="$(jq -c ".edges[$i].node" <<< "$JSON")"
      defaultHead=''
      id="$(jq -r '.id' <<< "$json")"
      refs=()

      if [ "$(jq -r '.owner.url' <<< "$json")" = "https://github.com/$OWNER" ]; then

          nameWithOwner="$(jq -r '.nameWithOwner' <<< "$json")"
          repoName="$(jq -r '.name' <<< "$json")"
#          repo="${OWNER}/${repoName}"
          repo="$nameWithOwner"
          defaultBranch="$(jq -r '.defaultBranchRef.name' <<< "$json")"
          if [ "$(jq -r '.refs.edges|length' <<< "$json")" -gt 0 ]; then
              while true; do
                  eval "$(getRefs 'refs' "$(jq -c '.refs.edges' <<< "$json")")"
                  [ "$(jq -r '.refs.pageInfo.hasNextPage' <<< "$json")" != 'true' ] && break
                  lastRef="$(jq -r '.refs.pageInfo.endCursor' <<< "$json")"
                  json="$(nextRefs "$id" "$lastRef")"
              done
          fi

          if [ -z "${refs['main']:-}" ] && [ "${defaultHead:-}" ]; then
              gh api --method POST   -H 'Accept: application/vnd.github+json' "/repos/${repo}/git/refs" -f ref='refs/heads/main' -f sha="$defaultHead" >/dev/null
              refs['main']="$defaultHead"
          fi

          if [ "${defaultBranch:-}" ] && [ "$defaultBranch" != 'main' ] && [ "${refs['main']:-}" ]; then
              gh api --method PATCH  -H 'Accept: application/vnd.github+json' "/repos/${repo}" -f default_branch='main' >/dev/null
              count=$(( count + 1 ))
          else
              ocnt=$(( ocnt + 1 ))
          fi

          echo "$i:  $repo $defaultBranch $defaultHead" "${#refs[*]}"

      fi
    done

    if [ $count -eq 0 ]; then
        echo 'removing old master branches'
        for repo in "${!repos[*]}";do
          if [ "${refs['master']:-}" ]; then
                gh api --method DELETE -H 'Accept: application/vnd.github+json' "/repos/${repo}/git/refs/heads/master"
                echo
          fi
        done
    elif [ "$ocnt" -gt 0 ]; then
        echo "found $ocnt repos which do npt have default branch as 'main'"
    fi
}


declare script="$(basename "$0")"
main "$(getRepos)" | tee "${script%.*}.log"
