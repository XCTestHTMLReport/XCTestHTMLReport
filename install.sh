#!/bin/bash

set -e

VERSION=$1

if [ -z $VERSION ] ; then
VERSION="2.0.0"
fi

OUT_ZIP="xchtmlreport.zip"

printf "Downloading xchtmlreport $VERSION\n"


CURL=$(curl -L -s -w "%{http_code}" -o $OUT_ZIP https://github.com/TitouanVanBelle/XCTestHTMLReport/releases/download/$VERSION/xchtmlreport-$VERSION.zip)

if [ ! -f $OUT_PATH ]; then
  printf '\e[1;31m%-6s\e[m' "Failed to download XCTestHTMLReport. Make sure the version you're trying to download exists."
  printf '\n'
  exit 1
fi

unzip $OUT_ZIP

BUILD_DIR="XCTestHTMLReport-$VERSION"

cd $BUILD_DIR
swift build -c release

chmod 755 .build/release/xchtmlreport
mv .build/release/xchtmlreport /usr/local/bin/

cd ".."
rm $OUT_ZIP
rm -rf $BUILD_DIR

printf '\e[1;32m%-6s\e[m' "Successully installed XCTestHTMLReport. Execute xchtmlreport -h for help."
printf '\n'
exit 0
