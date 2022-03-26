#!/bin/bash

while [ $# -gt 0 ]; do
  nodeArg=$1
  exec <$HADOOP_CONF_DIR/rack_topology.data
  result=""
  while read line; do
    ar=($line)
    if [ "${ar[0]}" = "$nodeArg" ]; then
      result="${ar[1]}"
    fi
  done
  shift
  if [ -z "$result" ]; then
    echo "/default-rack"
  else
    echo "$result"
  fi
done
