#/usr/bin/env bash

# Assumes package names are words (no special characters)
_spkg_completions() {
        local opts

        if (( COMP_CWORD == 1 )); then
                COMPREPLY=($(compgen -W "build install list uninstall" -- "${COMP_WORDS[1]}"))
        elif (( COMP_CWORD > 1 )); then 
                if [[ ${COMP_WORDS[COMP_CWORD]::1} == '-' ]]; then
                        case ${COMP_WORDS[1]} in
                                build ) opts=( '-b' '-c' '-p' '-bc') ;;
                                install ) opts=( '-y' '-f' '-fy' '-yf') ;;
                                uninstall ) opts=( '-y' ) ;;
                                list ) opts=( '-a' '-i' '-p' '-d' ) ;;
                                * ) opts=() ;;
                        esac
                else
                        case ${COMP_WORDS[1]} in
                                build ) opts=( $(spkg list -d | grep '^..d' | awk '{print $2}' ) ) ;;
                                install ) 
                                        g='^.p'
                                        for (( i = 2 ; i < COMP_CWORD ; i++ )); do
                                                if [[ ${COMP_WORDS[i]} =~ 'f' ]]; then
                                                        g='^i'
                                                        break
                                                fi
                                        done
                                        opts=( $(spkg list | grep "$g" | awk '{print $2}' ) ) ;;
                                        uninstall ) opts=( $(spkg list | grep '^i' | awk '{print $2}' ) ) ;;
                                * ) opts=() ;;
                        esac
                        compopt -o nospace
                fi

                if (( ${#opts[@]} )); then
                        COMPREPLY=($(compgen -W "${opts[*]}" -- "${COMP_WORDS[COMP_CWORD]}"))
                fi
        fi
}

complete -F _spkg_completions spkg
