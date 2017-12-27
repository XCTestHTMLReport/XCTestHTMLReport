#!/bin/bash

BRANCH=$1

if [ -z $BRANCH ] ; then
BRANCH="master"
fi

printf "Downloading xchtmlreport from $BRANCH\n"

CURL=$(curl -s -w "%{http_code}" -o xchtmlreport https://raw.githubusercontent.com/TitouanVanBelle/XCTestHTMLReport/$BRANCH/xchtmlreport)

if [ $CURL != "200" ]; then
  printf '\e[1;31m%-6s\e[m' "Failed to download XCTestHTMLReport. Make sure the version you're trying to download exists."
  printf '\n'
  exit 1
fi

chmod 755 xchtmlreport
mv xchtmlreport /usr/local/bin/

printf '\e[1;32m%-6s\e[m' "Successully installed XCTestHTMLReport. Execute xchtmlreport -h for help."
printf '\n'
exit 0
