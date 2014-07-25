#!/bin/bash
set -o pipefail

if [[ "$#" -ne "1" ]]; then
	echo "Invalid parameter count."
	echo "Usage: `basename $0` expected_table_count"
	exit 1;
fi

exp_table_count=$1

export work=/u01/oradata/dbstage/pdc_temp
export file_stub=stormodb_shire_storetw_Weekly
export explog=${file_stub}_expdp.log
export expref=${file_stub}_expdp.ref
export http_base=http://www.epa.gov/storet/download/storetw
export date_suffix=`date +%Y%m%d_%H%M`

cd $work

(
curl $http_base/$explog > $explog 2> curlout.log.1

egrep '^Export|successfully completed' $explog
export table_count=`grep "exported " $explog | wc -l`
export complete_count=`grep "successfully completed" $explog | wc -l`

if [ "$table_count" -lt "$exp_table_count" -o "$complete_count" -ne "1" ]; then
	echo "table_count("$table_count") less than $exp_table_count or complete_count("$complete_count") not 1. quitting."
	exit 1
fi

if [ -f $expref ]; then
	diff $explog $expref > /dev/null 2>$1 || echo "Differences found."
	if [ $? -eq 0 ]; then
		echo "Since no differences, we are done."
		exit 1
	elif [ $? -gt 1]; then
		echo "Error running [diff $explog $expref]."
		exit $?
	fi
else
	echo "No reference for comparison."
fi

files=`grep orabackup $explog | sed -e 's/^.*\//http:\/\/www.epa.gov\/storet\/download\/storetw\//'`
echo $files
echo $files | xargs -n 1 -P 8 wget -q

) 2>&1 | tee storet_dump_$date_suffix.out
