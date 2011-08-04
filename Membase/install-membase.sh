#!/bin/sh -e

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
rsync -a "$topdir/install/" "$dest/"
cp "$PROJECT_DIR/Membase/erl" "$dest/bin/erl"
cp "$PROJECT_DIR/Membase/erl" "$dest/lib/erlang/bin/erl"
cp "$PROJECT_DIR/Membase/start.sh" "$dest/start.sh"
rm "$dest/etc/membase/static_config"
cp "$topdir/ns_server/etc/static_config.in" "$dest/etc/membase/static_config.in"

mkdir -p "$dest/priv" "$dest/logs" "$dest/config" "$dest/tmp"
cp "$topdir/ns_server/priv/init.sql" \
    "$BUILT_PRODUCTS_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/init.sql"

cd "$dest"

# Fun with libraries
for f in bin/*
do
    fn="$dest/$f"
    otool -L "$fn" | egrep -v "^[/a-z]" | grep -v /usr/lib \
	| grep -v /System \
        | sed -e 's/(\(.*\))//g' | clean_lib "$fn"
done

# Fun with libraries
for fn in "$dest"/lib/*.dylib
do
    otool -L "$fn" | egrep -v "^[/a-z]" | grep -v /usr/lib \
	| grep -v /System \
        | sed -e 's/(\(.*\))//g' | clean_lib "$fn"
done
