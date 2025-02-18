#!/bin/bash

echo "Setting up environment..."
# Setting subenv var for the IAM instance role
if [[ $(hostname) == *"eng"* ]]; then
  ENV=eng
elif [[ $(hostname) == *"srv"* ]]; then
  ENV=srv
else
  ENV=com
fi

SUBENV_LOWER="{{SUBENV}}" # Getting subenv which is lowercase
SUBENV=${SUBENV_LOWER^^} # Safe solution to convert subenv to uppercase

# Fetching EFS details
EFS_ID=$(grep efs_id $FILE | cut -d '"' -f2)
EFS_ARN=$(aws efs describe-file-systems --file-system-id $EFS_ID --query "FileSystems[*].FileSystemArn" --output text)
KMS_KEY=$(aws efs describe-file-systems --file-system-id $EFS_ID --query "FileSystems[*].KmsKeyId" --output text)
PERF_MODE=$(aws efs describe-file-systems --file-system-id $EFS_ID --query "FileSystems[*].PerformanceMode" --output text)
if [[ $SUBENV_LOWER == "ppe" ]]; then
  IAM_ROLE_ARN=$(aws iam get-role --role-name $ENV-application-instance-role --query "Role.Arn" --output text)
else
  IAM_ROLE_ARN=$(aws iam get-role --role-name $ENV-$SUBENV-application-instance-role --query "Role.Arn" --output text)
fi

# Creating a token with the current date
TOKEN=etl_efsrestore_$(date + "$d-$m-$y")

# Setting AWS CLI output to use regular datetime
aws configure set cli_timestamp_format iso8601
echo "Done." && echo

# List out last 15 recovery points in a nice table, showing the ARN and Completion date
echo "Listing out last 15 recovery points for the mounted EFS:"
aws backup list-recovery-points-by-backup-vault --backup-vault-name "etl_backups" \
--by-resource-arn "$EFS_ARN" --query "RecoveryPoints[:15].[RecoveryPointArn, CompletionDate]" --output table

# Don't want to automatically restore a random one so asking the user to choose a backup from the results
echo "Please copy the ARN of the recovery point you wish to restore from the shown results."
read -p "ARN: " RECOVERY_ARN
echo
echo "Selected recovery ARN: "$RECOVERY_ARN

# Starting backup restore to the EFS and saving the restore job ID in a file
echo "Starting backup restoration to the EFS..."
aws backup start-restore-job --recovery-point-arn $RECOVERY_ARN \
--iam-role-arn $IAM_ROLE_ARN \
--metadata file-system-id=$EFS_ID,Encrypted=True,KmsKeyId=$KMS_KEY,PerformanceMode=$PERF_MODE,CreationToken=$TOKEN,newFileSystem=false > /tmp/restore_job_id.tmp

RESTORE_ID=$(grep RestoreJobId /tmp/restore_job_id.tmp | cut -d '"' -f 4)

while [[ $(aws backup describe-restore-job --restore-job-id $RESTORE_ID --query "Status" --output text | tee /tmp/restore_status.tmp) != "COMPLETED" ]]; do
  if [[ $(cat /tmp/restore_status.tmp) == "FAILED" ]]; then
    echo "The backup restoration has failed, reason: "
    aws backup describe-restore-job --restore-job-id $RESTORE_ID --query "StatusMessage"
    exit 1
  else
    # Add progress %?
    echo "Sleeping for 30 seconds..."
    sleep 30
  fi
done

echo "AWS Backup restoration has finished sucessfully; The restored backup is at '/mnt/efs/aws-backup-restore'" && echo

COUNT=0
while [[ $COUNT -le 3 ]]; do
  read -p "Do you want to copy the restored files right away? (y/n) " $REPLY
  if [[ $REPLY == "Y" || $REPLY == "y" ]]; then
    echo "Renamed /mnt/efs/opt/ into /mnt/efs/opt.old for backup."
    mv /mnt/efs/opt{,.old}
    echo "Starting rsync..."
    # Copying over the backup using rsync (a)rchive, (z)ipped, (h)uman-readable; progress2 shows only the total percentage instead of individual files
    rsync -azh --info=progress2 /mnt/efs/aws-backup-restore*/* /mnt/efs/
    break
  elif [[ $REPLY == "N" || $REPLY == "n" ]]; then
    echo "Cleaning tmp files and exiting script..."
    rm /tmp/restore_job_id.tmp && rm /tmp/restore_status.tmp
    echo "Run the following command when you want to copy the backup: rsync -azh --info=progress2 /mnt/efs/aws-backup-restore*/* /mnt/efs/"
    exit 0
  else
    echo "Please reply with Y/y or N/n." && echo
    COUNT=$((COUNT+1))
    continue
  fi
done

echo "Cleaning tmp files and exiting script..."
rm /tmp/restore_job_id.tmp && rm /tmp/restore_status.tmp
