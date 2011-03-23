#!/bin/sh -e

instdir=${SRCROOT%dependencies/couchdbx-app}
builddir="${instdir}build/"
topdir="$PROJECT_DIR/.."

dest="$BUILT_PRODUCTS_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/membase-core"

clean_lib() {
    while read something
    do
        base=${something##*/}
        echo "Fixing $1 $something -> $dest/lib/$base"
        test -f "$dest/lib/$base" || cp "$something" "$dest/lib/$base"
        chmod 755 "$dest/lib/$base"
        install_name_tool -change "$something" "lib/$base" "$1"
    done
}

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

# Fun with libraries
for f in bin/memcached/memcached bin/moxi/moxi \
    bin/vbucketmigrator/vbucketmigrator
do
    fn="$dest/$f"
    otool -L "$fn" | egrep -v "^[/a-z]" | grep -v /usr/lib \
        | sed -e 's/(\(.*\))//g' | clean_lib "$fn"
done

# Fun with libraries
for fn in "$dest"/lib/*.dylib
do
    otool -L "$fn" | egrep -v "^[/a-z]" | grep -v /usr/lib \
        | sed -e 's/(\(.*\))//g' | clean_lib "$fn"
done
