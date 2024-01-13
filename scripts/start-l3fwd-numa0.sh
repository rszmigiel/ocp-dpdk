#!/bin/bash

MAX=8

RANGE=`taskset -c -p 1 | cut -d: -f2 | tr -d ' '`
PHYS_CORES=`lscpu -p=CORE | grep -v '^#' | sort -n | uniq`
cpus=()
IFS=","
for i in ${RANGE}
do
  if [[ "${i}" =~ ^[0-9]+-[0-9]+$ ]]
    then IFS="-" read -r -a cpu_range <<< ${i}
    for ((n=${cpu_range[0]}; n<=${cpu_range[1]}; n++))
    do
      cpus+=(${n})
    done
  else
      cpus+=(${i})
  fi
done

IFS=$'\n' cpus_sorted=($(sort -n <<<"${cpus[*]}"))

echo ${cpus_sorted[@]}

echo "Fist CPU: ${cpus_sorted[0]}"
echo "Second CPU: ${cpus_sorted[+1]}"
echo "Last CPU: ${cpus_sorted[-1]}"
echo "Number of CPUs: ${#cpus_sorted[@]}"

IFS="," read -a NICS <<< $(env | sed -nr 's/(PCIDEVICE_OPENSHIFT_IO_)([0-9A-Z]+)(.*)/\2/p' | sort -u | tr "\n" ",")

echo "PFs to be used: ${NICS[@]}"

for NIC in ${NICS[@]}
 do
   echo ${NIC}
   PCIADDRS=PCIDEVICE_OPENSHIFT_IO_${NIC}
   echo ${!PCIADDRS}
 done

IFS="," read -r -a A_NIC1 <<< ${PCIDEVICE_OPENSHIFT_IO_ENS66F0}
IFS="," read -r -a A_NIC2 <<< ${PCIDEVICE_OPENSHIFT_IO_ENS66F1}

echo "Number of ports on NIC1: ${#A_NIC1[@]}"
echo "Number of ports on NIC2: ${#A_NIC2[@]}"

NIC1=$(for (( c=0; c<$MAX; c++)); do printf -- "-a ${A_NIC1[$c]} "; done)
NIC2=$(for (( c=0; c<$MAX; c++)); do printf -- "-a ${A_NIC2[$c]} "; done)

CPUPPORT=$(( ${#cpus_sorted[@]} / $(( $MAX*2 )) ))
echo "CPU per PORT ratio: ${CPUPPORT}"

set -x

eval ./dpdk-l3fwd \
	-l ${RANGE} \
        -n 4 \
        ${NIC1} \
        ${NIC2} \
        --proc-type=auto \
        --file-prefix=test112 \
        -- \
        -p 0xFFFFFFFF \
	--config=$(printf \"; cc=0 ;for (( c=0; c<$(( $MAX * 2 )); c++)); do for (( q=0; q<${CPUPPORT}; q++ )); do printf "($c,$q,${cpus_sorted[$((cc++))]}),"; done; done | sed 's/,$//' ; printf \") \
        --parse-ptype \
        -P \
        $(for (( c=0; c<$MAX; c++ )); do printf -- "--eth-dest=$c,ba:be:01:01:01:%02x " $c; done ) \
        $(for (( c=0; c<$MAX; c++ )); do printf -- "--eth-dest=$(($c+$MAX)),ba:be:02:02:02:%02x " $c; done )

