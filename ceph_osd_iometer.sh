#!/bin/bash
# Version: 1.0
# Author: Yu-Jung Cheng

set -o errexit

QUEUE_SIZE=5
SLEEP_INTERVAL=0.995
OUTPUT_FILE=""
DURATION=0


declare -a TARGET_OSD_ID
declare -A READ_BYTES
declare -A WRITE_BYTES
declare -A OSD_PID_ID
declare -A INITIAL_READ_BYTES
declare -A INITIAL_WRITE_BYTES


for argument in "$@"
do
    case $argument in
        -osd=*)
            id_str=${argument##-osd=}
            TARGET_OSD_ID=(${id_str//,/ })
            ;;
        -o=*)
            OUTPUT_FILE=${argument##-o=}
            > $OUTPUT_FILE
            ;;
        -t=*)
            DURATION=${argument##-t=}
            if [[ $DURATION != ?(-)+([0-9]) || $DURATION == 0 ]]; then
                echo "Invalid duration value! ($DURATION)"
                exit
            fi
            ;;
    esac
done


ceph_osd_id_pid=($(ps -ef|grep "/usr/bin/ceph-osd" | grep -v "grep" | awk '{print $2, $13}'))


for ((i=0; i<${#ceph_osd_id_pid[@]}; i=i+2))
do
    osd_pid=${ceph_osd_id_pid[$i]}
    osd_id=${ceph_osd_id_pid[$i+1]}

    if [[ "$TARGET_OSD_ID" -eq "" ]]; then
        OSD_PID_ID[$osd_pid]=${osd_id}
    else
        for t_osd_id in "${TARGET_OSD_ID[@]}"
        do
            if [[ "${t_osd_id}" -eq "${osd_id}" ]]; then
                OSD_PID_ID[$osd_pid]=${osd_id}
            fi
        done
    fi

done

#echo ${OSD_PID_ID[@]}
#echo ${!OSD_PID_ID[@]}

begin_timestamp=`date +%s`


for ((i=0; i<${QUEUE_SIZE}; i=i+1))
do
    for pid in "${!OSD_PID_ID[@]}"
    do
        osd_rw_bytes=($(cat /proc/$pid/io | grep -A1 read_bytes | awk '{print $2}'))
        READ_BYTES[$pid, $i]=${osd_rw_bytes[0]}
        WRITE_BYTES[$pid, $i]=${osd_rw_bytes[1]}

        INITIAL_READ_BYTES[$pid]=${osd_rw_bytes[0]}
        INITIAL_WRITE_BYTES[$pid]=${osd_rw_bytes[1]}
    done
done

start_time=`date +"%T.%3N"`

for ((i=0; i<$QUEUE_SIZE; i=i+1))
do

    clear
    time=`date +"%T.%3N"`

    echo "[ID] [PID] [Read Bytes]  [Write Bytes]  [Total Read Bytes]  [Total Write Bytes]"

    for pid in "${!OSD_PID_ID[@]}"
    do
        osd_rw_bytes=($(cat /proc/$pid/io | grep -A1 read_bytes | awk '{print $2}'))

        READ_BYTES[$pid, $i]=${osd_rw_bytes[0]}
        WRITE_BYTES[$pid, $i]=${osd_rw_bytes[1]}

        j=$(($i+1))
        if [ $j -eq $QUEUE_SIZE ] ; then
            j=0;
        fi

        #rx=$(((${READ_BYTES[$pid, $i]}-${READ_BYTES[$pid, $j]})/${QUEUE_SIZE}))
        #wx=$(((${WRITE_BYTES[$pid, $i]}-${WRITE_BYTES[$pid, $j]})/${QUEUE_SIZE}))

        rx=$(((${osd_rw_bytes[0]}-${READ_BYTES[$pid, $j]})/${QUEUE_SIZE}))
        wx=$(((${osd_rw_bytes[1]}-${WRITE_BYTES[$pid, $j]})/${QUEUE_SIZE}))

        t_rb=$((${osd_rw_bytes[0]}-${INITIAL_READ_BYTES[$pid]}))
        t_wb=$((${osd_rw_bytes[1]}-${INITIAL_WRITE_BYTES[$pid]}))

        printf "%-4s %-5s %'12d  %'13d  %'18d  %'19d\n" ${OSD_PID_ID[$pid]}  $pid  $rx  $wx $t_rb $t_wb

        if [[ -z $OUTPUT_FILE ]]; then
            echo $time ${OSD_PID_ID[$pid]} $pid $rx $wx $t_rb $t_wb >> $OUTPUT_FILE
        fi
    done


    if [ $i -eq $((${QUEUE_SIZE}-1)) ]; then
        i=-1
    fi

    if [[ $DURATION != 0 ]]; then
        current_timestamp=`date +%s`
        time_passed=$((current_timestamp - begin_timestamp))
        if [[ $time_passed -ge $DURATION ]]; then
            echo -e "\nStart at $start_time, Exit at $time"
            exit
        fi
        time="$time, start at $start_time, exit after $((DURATION - time_passed)) seconds."
    fi

    echo -e "\n$time"

    sleep ${SLEEP_INTERVAL}
done
