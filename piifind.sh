#!/usr/bin/env bash

default_pii_patterns="name|email|address|zip-code"
pii_patterns=$default_pii_patterns

function usage_exit {
    cat <<EOF
Usage: piifind [-a "foo|bar|hoge"] [FILE]

e.g. Basic usage
piifind src/

e.g. With additional PII patterns to look for
piifind -a billing|phone src/

e.g. Reading from STDIN
piifind <<EOD
(log "print address %s" address)
EOD

EOF
    exit 0
}

while getopts p:h OPT
do
    case $OPT in
        p)  extra_patterns=$OPTARG
            ;;
        h)  usage_exit
            ;;
        \?) usage_exit
            ;;
    esac
done
shift $(($OPTIND - 1))

if [ ! -z "$extra_patterns" ]; then
    pii_patterns="${pii_patterns}|$extra_patterns"
fi

# Positive lookahead looking for a form that starts from
# one of the common logging fns. There must be a better way
# so that I don't need to repeaset \( but I couldn't figure out.
log_fn_regex="\(log|\(info|\(warn|\(error|\(debug"

# Good enough regex that looks for a Clojure form that starts with one of common log fns
# followed by one of $pii_patterns.
# Examples that match
# (infof "debug: %s"
#        address)
# https://regex101.com/r/hWN5LB/1
# We need to check regex1 (looking for forms starting from log fns)
# and then check regex2 (looking for PII keywords inside strings matched with regex1)
regex1="(?=${log_fn_regex})(\((?:[^()]+|(?1))+\))"
regex2="\b${pii_patterns}\b"
grep_opt1="--ignore-case --perl-regexp --with-filename --only-matching --null-data --color=auto"
grep_opt2="--ignore-case --perl-regexp --text --color=auto"

if [ ! -z "$1" ]; then
    echo "Reading from file: $1"
    if [ ! -e $1 ]; then
        echo "File not found: $1"
        exit 1
    fi

    find $1 \( -name \*.clj -or -name \*.cljs \) | xargs grep $grep_opt1 $regex1 | grep $grep_opt2 $regex2
else
    echo "Reading from stdin"
    cat - | grep $grep_opt1 $regex1 | grep $grep_opt2 $regex2
fi

# Grep returns 0 if matchs
if [ $? -eq 0 ]; then
    cat <<EOF


*************************************************************
Possibly logging PII in your code!! Check the output above
and make sure code doesn't accidentally logs PII.
*************************************************************
EOF
    exit 1
else
    echo "No PII :)"
    exit 0
fi
