#!/bin/bash

curl -o xchtmlreport https://raw.githubusercontent.com/TitouanVanBelle/XCUITestHTMLReport/master/xchtmlreport
chmod 755 xchtmlreport
mv xchtmlreport /usr/local/bin/
printf "\nSuccessully installed XCUITestHTMLReport. Execute xchtmlreport -h for help\n"
