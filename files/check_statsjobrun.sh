#!/bin/bash

POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -W|--warn)
    warn="$2"
    shift # past argument
    shift # past value
    ;;
    -S|--stat)
    stat="$2"
    shift # past argument
    shift # past value
    ;;
    -C|--critical)
    critical="$2"
    shift # past argument
    shift # past value
    ;;
    *)    # unknown option
    POSITIONAL+=("$1") # save it in an array for later
    shift # past argument
    ;;
esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters

if [[ -z "$stat" ]]; then
     echo "CYGLASS-STATSJOB UNKNOWN - missing argument -S"
     exit 3
fi

re='^[0-9]+$'

#echo warn         = "${warn}"
if [[ -z "$warn" ]]; then
     echo "CYGLASS-STATSJOB UNKNOWN - missing argument -W"
     exit 3
elif [[ ! $warn =~ $re ]]; then
     echo "CYGLASS-STATSJOB UNKNOWN - invalid argument -W should be a number ($warn)"
     exit 3
fi

#echo critical     = "${critical}"
if [[ -z "$critical" ]]; then
     echo "CYGLASS-STATSJOB UNKNOWN - missing argument -C"
     exit 3
elif [[ ! $critical =~ $re ]]; then
     echo "CYGLASS-STATSJOB UNKNOWN - invalid argument -C should be a number ($critical)"
     exit 3
fi

if [[ ! "$warn" -lt "$critical" ]]; then
     echo "CYGLASS-STATSJOB UNKNOWN - invalid argument -W ($warn) must be less than -C ($critical)"
     exit 3
fi

tmpfile1=$(mktemp /tmp/cyglass_statsjob.out.XXXXXX)

query=`echo "{\"sort\":{\"endtime\":{\"order\":\"desc\"}},\"size\":1,\"query\":{\"bool\":{\"must_not\":{\"term\":{\"imported.${stat}\":0}}}}}"`
curl -XGET http://cyglassCDH1:9200/statsjobrun/_search -H 'Content-Type: application/json' -d $query 2> /dev/null 1> $tmpfile1

last_stat=`cat $tmpfile1 | jq '.hits.hits[0]._source.endtime'`
filter=`echo ".hits.hits[0]._source.imported.$stat"`
last_stat_value=`cat $tmpfile1 | jq $filter`

now=`date +%s`
now=`echo "${now}000"`

if [[ "$last_stat" == "null" ]]; then
        echo "CYGLASS-STATSJOB CRITICAL - $stat always 0"
        exit 2
fi

if [[ "$last_stat_value" == "null" ]]; then
        echo "CYGLASS-STATSJOB UNKNOWN - $stat not found"
        exit 3
fi

delta_ms=$((now-last_stat))
delta_sec=$((delta_ms/1000))
delta_min=$((delta_sec/60))

delta_hrs=$((delta_min/60))

rc=0

if [[ "$delta_hrs"  -gt "${warn}" ]]; then
		
		#This is the warning level....at least	
        if (( rc < 1)); then rc=1; fi
		
		if [[ "$delta_hrs" -gt "${critical}" ]]; then
			#This is critical
			if (( rc < 2 )); then rc=2; fi
        fi
 fi

optional_perfdata=

rm $tmpfile1

if [[ "$rc" -eq "0" ]]; then
	service_output="CYGLASS-STATSJOB OK - Last value of ${stat} was ${last_stat_value};"
elif [[ "$rc" -eq "1" ]]; then
   service_output="CYGLASS-STATSJOB WARNING - ${delta_hrs} hrs since ${stat} was not zero > ${warn};"
else
   service_output="CYGLASS-STATSJOB CRITICAL - ${delta_hrs} hrs since ${stat} was not zero > ${critical};"
fi

echo -e "${service_output}"
exit $rc
