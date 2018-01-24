
#!/bin/bash

# A simple Bash script for creating snapshots of EBS volumes attached to EC2
# instances based on tags. This approach doesn't make any effort to
# ensure that the volumes are quiesced prior to the snapshot.
# The script also copies tags from the instance and applies them to the snapshot.

# Fail out of script if any command fails.
set -e
set +

export AWS_DEFAULT_REGION=us-east-1

# Tag name and value to use in identifying target instances
TARGET_TAG_NAME=${TARGET_TAG_NAME:-"Service"}
TARGET_TAG_VALUE=${TARGET_TAG_VALUE:-"cu-aws-accounts"}

# Tags and information to attached to the snapshot
SNAPSHOT_DESCRIPTION=${SNAPSHOT_DESCRIPTION:-"jenkins-ebs-snap"}
MAX_AGE_TAG=${MAX_AGE_TAG:-"ebs-snap-max-age-days"}
MAX_AGE_TAG_VALUE=${MAX_AGE_TAG_VALUE:-7}

TARGET_INSTANCES=`aws ec2 describe-instances --filters "Name=tag:$TARGET_TAG_NAME,Values=$TARGET_TAG_VALUE" --query Reservations[].Instances[].InstanceId --output text`

for INSTANCE in $TARGET_INSTANCES
do
  echo Target instance: $INSTANCE

	VOLUMES=`aws ec2 describe-volumes --filter Name=attachment.instance-id,Values=$INSTANCE --query Volumes[].VolumeId --output text`

	for VOLUME in $VOLUMES
	do
		echo Creating snapshot for $VOLUME
    TAGS=`aws ec2 describe-volumes --volume-ids $VOLUME --query Volumes[].Tags[]`
    cat <<EOF > tmp.json
{ "Tags": $TAGS
}
EOF
    SNAPSHOT_ID=`aws ec2 create-snapshot --volume-id $VOLUME --description "$SNAPSHOT_DESCRIPTION" --query SnapshotId --output text`
    echo Creating snapshot ID $SNAPSHOT_ID
    aws ec2 create-tags --resources $SNAPSHOT_ID --tags Key="$MAX_AGE_TAG",Value=$MAX_AGE_TAG_VALUE
    if [ "$TAGS" != "[]" ];
    then
      echo Adding tags: $TAGS
      aws ec2 create-tags --resources $SNAPSHOT_ID --cli-input-json file://tmp.json
    fi
	done

done
