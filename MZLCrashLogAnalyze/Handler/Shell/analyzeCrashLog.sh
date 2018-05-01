#!/bin/sh

export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

symbolicatecrash=$1
ipsPath=$2
dsymPath=$3
outputPath=$4

$symbolicatecrash $ipsPath $dsymPath > $outputPath
