#!/bin/sh -e

instdir=${SRCROOT%dependencies/couchdbx-app}
builddir="${instdir}build/"
topdir="$PROJECT_DIR/.."

dest="$BUILT_PRODUCTS_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/membase-core"

# ns_server bits
for p in start_shell.sh browse_logs deps ebin
do
    rsync -a "$topdir/ns_server/$p" "$dest/$p"
done

mkdir -p "$dest/priv" "$dest/logs" "$dest/config" "$dest/tmp"
cp "$topdir/ns_server/priv/init.sql" \
    "$BUILT_PRODUCTS_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/init.sql"

# Memcached and engines.
mkdir -p "$dest/bin/memcached" "$dest/bin/bucket_engine"
mkdir -p "$dest/bin/ep_engine" "$dest/bin/moxi" "$dest/bin/vbucketmigrator"

cp "$topdir/bucket_engine/.libs/bucket_engine.so" "$dest/bin/bucket_engine"
cp "$topdir/ep-engine/.libs/ep.so" "$dest/bin/ep_engine/"
for f in default_engine.so stdin_term_handler.so syslog_logger.so
do
    cp "$topdir/memcached/.libs/$f" "$dest/bin/memcached/"
done
cp "$topdir/memcached/memcached" "$dest/bin/memcached/memcached"

# Moxi
cp "$topdir/moxi/moxi" "$dest/bin/moxi/moxi"

# vbm
cp "$topdir/vbucketmigrator/vbucketmigrator" \
    "$dest/bin/vbucketmigrator/vbucketmigrator"
