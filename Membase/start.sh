#!/bin/sh

MEMBASE_TOP=`pwd`
export MEMBASE_TOP

DYLD_LIBRARY_PATH="$MEMBASE_TOP:$MEMBASE_TOP/lib"
export DYLD_LIBRARY_PATH

echo DYLD_LIBRARY_PATH is "$DYLD_LIBRARY_PATH"

erl -noshell -setcookie nocookie -sname init -run init stop 2>&1 > /dev/null
if [ $? -ne 0 ]
then
    exit 1
fi

datadir="$HOME/Library/Application Support/Membase"

test -d "$datadir" || mkdir -p "$datadir"
cd "$datadir"

ERL_LIBS="$MEMBASE_TOP/lib/couchdb/erlang/lib:$MEMBASE_TOP/lib/ns_server/erlang/lib"
export ERL_LIBS

DONT_START_COUCH=1
export DONT_START_COUCH

mkdir -p "$datadir/etc/membase"

sed -e "s|@DATA_PREFIX@|$datadir|g" -e "s|@BIN_PREFIX@|$MEMBASE_TOP|g" \
    "$MEMBASE_TOP/etc/membase/static_config.in" > "$datadir/etc/membase/static_config"

exec erl \
    +A 16 \
    -setcookie nocookie \
    -kernel inet_dist_listen_min 21100 inet_dist_listen_max 21299 \
    $* \
    -run ns_bootstrap -- \
    -ns_server config_path "\"$datadir/etc/membase/static_config\"" \
    -ns_server pidfile "\"$datadir/membase-server.pid\"" \
    -ns_server dont_suppress_stderr_logger true
