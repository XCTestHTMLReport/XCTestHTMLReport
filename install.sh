#!/bin/bash

set -e

VERSION=$1

if [ -z $VERSION ] ; then
VERSION="1.6.0"
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

chmod 755 xchtmlreport
mv xchtmlreport /usr/local/bin/

rm $OUT_ZIP

printf '\e[1;32m%-6s\e[m' "Successully installed XCTestHTMLReport. Execute xchtmlreport -h for help."
printf '\n'
exit 0
