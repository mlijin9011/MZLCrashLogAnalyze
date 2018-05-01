#!/bin/sh

#cp `find /Applications/Xcode.app/Contents/SharedFrameworks -name symbolicatecrash -type f` ~/Downloads/CrashLog

ln -s `find /Applications/Xcode.app/Contents/SharedFrameworks -name symbolicatecrash -type f` ~/Downloads/CrashLog/symbolicatecrash

