#!/bin/bash
source config/l3fwd.cfg
IFS="," read -a CORELIST <<< $(taskset -c -p 1  | cut -d: -f2 | sed 's/[[:blank:]]//g')
./dpdk-l3fwd -l ${CORELIST[0]},${CORELIST[1]} -n 5 -a ${NIC1} -a ${NIC2} --proc-type=auto --file-prefix=${PREFIX} -- -p 0x3 --config="(0,0,${CORELIST[0]}),(1,0,${CORELIST[1]})" --parse-ptype -P
