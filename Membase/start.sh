#!/bin/sh

MEMBASE_TOP=`pwd`
export MEMBASE_TOP

erl -noshell -setcookie nocookie -sname init -run init stop 2>&1 > /dev/null
if [ $? -ne 0 ]
then
    exit 1
fi

datadir="$HOME/lib/Application Support/Membase"

test -d "$datadir" || mkdir -p "$datadir"
cd "$datadir"

ERL_LIBS="$MEMBASE_TOP/lib/couchdb/erlang/lib:$MEMBASE_TOP/lib/ns_server/erlang/lib"
export ERL_LIBS

DONT_START_COUCH=1
export DONT_START_COUCH

exec erl \
    +A 16 \
    -setcookie nocookie \
    -kernel inet_dist_listen_min 21100 inet_dist_listen_max 21299 \
    $* \
    -run ns_bootstrap -- \
    -ns_server config_path "\"$MEMBASE_TOP/etc/membase/static_config\"" \
    -ns_server pidfile "\"$datadir/membase-server.pid\"" \
    -ns_server dont_suppress_stderr_logger true