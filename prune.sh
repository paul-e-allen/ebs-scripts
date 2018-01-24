#!/bin/bash

# A simple Bash script for pruning snapshots of EBS volumes based on tags.
# Not efficient wrt API calls, but simple.

# Fail out of script if any command fails.
set -e
set +x

export AWS_DEFAULT_REGION=us-east-1

# Tags and information to attach to the snapshot
SNAPSHOT_DESCRIPTION=${SNAPSHOT_DESCRIPTION:-"jenkins-ebs-snap"}
MAX_AGE_TAG=${MAX_AGE_TAG:-"ebs-snap-max-age-days"}
DRY_RUN=${DRY_RUN:-true}


QUERY="Snapshots[*].[SnapshotId,StartTime,Tags[?Key=='$MAX_AGE_TAG'].Value[]|[0]]"
TARGETS=`aws ec2 describe-snapshots  --filters "Name=description,Values=$SNAPSHOT_DESCRIPTION" "Name=tag-key,Values=$MAX_AGE_TAG"  --query $QUERY --output text `

ARRAY=($TARGETS)
LENGTH=${#ARRAY[@]}
LAST_INDEX=$((LENGTH - 1))

for X in `seq 0 3 $LAST_INDEX`
do
  echo -----------------------
  SNAPSHOT_ID=${ARRAY[X]}
  CREATE_TIME=${ARRAY[((X+1))]}
  MAX_AGE=${ARRAY[((X+2))]}
  # echo $X, $SNAPSHOT_ID, $CREATE_TIME, $MAX_AGE
  # date "+%s" -d "2018-01-24T14:00:50.000Z"
  CREATE_TIME_EPOCH=`date "+%s" -d "$CREATE_TIME"`
  EXPIRE_EPOCH=$((CREATE_TIME_EPOCH + MAX_AGE * 24 * 60 * 60))
  NOW=`date "+%s"`

  #echo Now: $NOW
  #echo Create Time: $CREATE_TIME_EPOCH
  #echo Expireation: $EXPIRE_EPOCH

  echo Snapshot: $SNAPSHOT_ID created $CREATE_TIME with max age of $MAX_AGE days.

  if [ $NOW -ge $EXPIRE_EPOCH ]; then
    if [ "$DRY_RUN" = true ]; then
    	echo Snapshot is expired, but DRY_RUN is enabled so delete is not triggered.
    else
    	echo Snapshot is being deleted.
    	aws ec2 delete-snapshot --snapshot-id $SNAPSHOT_ID
  	fi
  else
  	echo Snapshot is not expired.
  fi
done