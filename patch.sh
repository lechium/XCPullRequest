#!/bin/bash

#"pushd '%@' ; git checkout master ; git am --signoff < '%@' ; git push origin master ; popd"

#$1 = project path
#$2 = patch path

rm /tmp/poutput
pushd "$1"
echo ""
git checkout master 1>/tmp/poutput 2>/tmp/poutput
output=`cat /tmp/poutput`
echo $output
echo ""
echo "Patching..."
echo ""
git am --signoff < "$2" 1>/tmp/poutput 2>/tmp/poutput
output=`cat /tmp/poutput`
echo ""
echo $output
echo ""
git push origin master 1>/tmp/poutput 2>/tmp/poutput
output=`cat /tmp/poutput`
echo $output
echo ""
popd