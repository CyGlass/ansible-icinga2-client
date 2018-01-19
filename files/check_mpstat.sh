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

re='^[0-9]+$'

#echo warn         = "${warn}"
if [[ -z "$warn" ]]; then
     echo "MPSTAT UNKNOWN - missing argument -W"
     exit 3
elif [[ ! $warn =~ $re ]]; then
     echo "MPSTAT UNKNOWN - invalid argument -W should be a number ($warn)"
     exit 3
fi

#echo critical     = "${critical}"
if [[ -z "$critical" ]]; then
     echo "MPSTAT UNKNOWN - missing argument -C"
     exit 3
elif [[ ! $critical =~ $re ]]; then
     echo "MPSTAT UNKNOWN - invalid argument -C should be a number ($critical)"
     exit 3
fi

if [[ ! "$warn" -lt "$critical" ]]; then
     echo "MPSTAT UNKNOWN - invalid argument -W ($warn) must be less than -C ($critical)"
     exit 3
fi

tmpfile1=$(mktemp /tmp/mpstat.out.XXXXXX)
tmpfile2=$(mktemp /tmp/cpu_stats.out.XXXXXX)

mpstat -A > $tmpfile1 
num_cpu=`cat $tmpfile1 | line | awk '{print  $(NF-1) }' | cut -b 2-`

#There are 4 header lines
head -$((num_cpu + 4)) $tmpfile1 | tail -$((num_cpu + 1)) > $tmpfile2

rc=0

while read p; do
  cpu_num=`echo $p | awk '{print $3}'`
  cpu_usr_per=`echo $p | awk '{print $4}'`
  cpu_usr=`echo $cpu_usr_per | tr -d .` 

  if [[ "$cpu_num" == "all" ]]; then
        total_cpu=$cpu_usr_per

  	if [[ "$cpu_usr"  -gt "${warn}00" ]]; then
		#This is the warning level....at least	
        	if (( rc < 1)); then rc=1; fi
	
        	if [[ "cpu_usr" -gt "${critical}00" ]]; then
			#This is critical
			if (( rc < 2 )); then rc=2; fi
        	fi
  	fi
  else
       #There are the per cpu stats
       cpu_long_output="CPU ${cpu_num} @ ${cpu_usr_per}%;"
       cpu_perfdata="cpu_${cpu_num}=${cpu_usr_per}%;${warn};${critical}"

       long_output="${long_output}\n${cpu_long_output}"

       if [[ -z "$optional_perfdata" ]]; then
            optional_perfdata="$cpu_perfdata\n"
       else
            perfdata="${perfdata}${cpu_perfdata} "
       fi
  fi 
  

done < $tmpfile2

rm $tmpfile1
rm $tmpfile2

if [[ "$rc" -eq "0" ]]; then
   service_output="MPSTAT OK - ${num_cpu} CPUs @ ${total_cpu}%;"
elif [[ "$rc" -eq "1" ]]; then
   service_output="MPSTAT WARNING - ${num_cpu} CPUs @ ${total_cpu}% > ${warn}%;"
else
   service_output="MPSTAT CRITICAL - ${num_cpu} CPUs @ ${total_cpu}% > ${critical}%;"
fi

echo -e "${service_output}|${optional_perfdata}${long_output}|${perfdata}"
exit $rc
