source ~/bin/bashlib
source ~/bin/git-prompt.sh

alias ac='add-content'
alias cbr='cbfRepos'
alias dc='docker-compose'
alias dd='docker-dependants'
alias de='docker exec -it'
alias dl='docker logs'
alias dr='docker run -it --rm --entrypoint bash'
alias dt='docker top'
alias dcs='dockerComposeServices'
alias dim='dockerImages'
alias dnt='dockerNetworks'
alias dps='dockerProcesses'
alias env='/usr/bin/env | sort'
alias fdd='docker-find-dependents'
alias fip='findInProjects'
alias gr='git-revision'
alias rcc='removeCurrentContainers'
alias rlg='dockerRunLogs'
alias roc='rmOldContainers'
alias dockviz='docker run -it --rm -v /var/run/docker.sock:/var/run/docker.sock nate/dockviz'

