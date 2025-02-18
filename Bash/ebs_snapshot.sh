#!/bin/bash
# This script will run EBS snapshots using AWS CLI; set as a cron on active Service and Engine nodes

set -x

DS_PASSWORD=$(jq -r ".is_admin_password" $FILE ) # Getting isadmin PW
SUBENV_LOWER="{{SUBENV}}" # Getting subenv which is lowercase
SUBENV=${SUBENV_LOWER^^} # Safe solution to convert subenv to uppercase
INSTANCE_ID=$(unset http_proxy; /usr/bin/curl --noproxy -s http://169.254.169.254/latest/meta-data/instance-id)
VOLUMES=$(aws ec2 describe-volumes --filters Name=attachment.instance-id,Values=$INSTANCE_ID --query "Volumes[*].VolumeId" --output text)
SRV_HOST={{ isf_server_host }}

echo "-----------------------------------------------"
echo "Script started at $(date)"
echo "-----------------------------------------------"

# Killing user sessions
echo "Killing user sessions..."
/opt/ibm/informationserver/ASBNode/bin/SessionAdmin.sh -url https://$SRV_HOST:9443 -user isadmin -password $DS_PASSWORD -kill-user-sessions

echo "Turning on maintenance mode.."
# Turning on maintenance mode
/opt/ibm/informationserver/ASBNode/bin/SessionAdmin.sh -url https://$SRV_HOST:9443 -user isadmin -password $DS_PASSWORD -set-maint-mode ON

# Commenting out monitor script because everything will be stopped
sed -i 's/.*monitor.sh.*/#&/' /var/spool/cron/root

# Stopping services; disabling CW alarms
if [[ $(hostname) == *"eng"* ]]; then
    aws cloudwatch disable-alarm-actions --alarm-names etl-$SUBENV-engine-health
    /mnt/efs/opt/ibm/informationserver/ASBNode/bin/NodeAgents.sh stop
    /mnt/efs/opt/ibm/informationserver/Server/DSEngine/bin/uv -admin -stop
elif [[ $(hostname) == *"srv"* ]]; then
    aws cloudwatch disable-alarm-actions --alarm-names etl-$SUBENV-service-health
    /tescobank/scripts/01_stop_all_service.sh
    su wasadm -c "cd /opt/IBM/WebSphere/AppServer/profiles/DmgrSrv01/bin; ./stopManager.sh; cd /opt/IBM/WebSphere/AppServer/profiles/AppSrv01/bin; ./stopServer.sh server1; ./stopNode.sh"
else
    echo "Exiting, please run this script from Service or Engine tier node."
    exit 1
fi

for volume in $VOLUMES;
    do aws ec2 create-snapshot --volume-id $volume --description "Host $(hostname | cut -d. -f1) - EBS backup for $volume" \
        --tag-specifications "ResourceType=snapshot,Tags=[{Key=ProjectName,Value=ETL}, {Key=Application,Value=ETL Engine Tier}]" \
        --query "SnapshotId" --output "text" >> /tmp/snapshot_id_$volume
done

# Inerating through volumes to check if they are done
for volume in $VOLUMES;
    while [[ $(aws ec2 describe-snapshots --snapshot-ids $(cat /tmp/snapshot_id_$volume) --query "Snapshots[].State" --output text | tee /tmp/snapshot_status_$volume) != "completed" ]]; do
        if [[ $(cat /tmp/snapshot_status_$volume) == "error" ]]; then
            echo "EBS snapshot has failed, reason: "
            aws ec2 describe-snapshots --snapshot-ids $(cat /tmp/snapshot_id_$volume)
            echo "Breaking out of the loop."
            break
        else
            # Showing progress for current volume
            echo "Currently at: $(aws ec2 describe-snapshots --snapshot-ids $(cat /tmp/snapshot_id_$volume) --query "Snapshots[].Progress" --output "text") for $volume."
            echo "Sleeping for 90 seconds..."
            sleep 90
        fi
    done
done

# Starting services; enabling CW alarms
if [[ $(hostname) == *"eng"* ]]; then
    /mnt/efs/opt/ibm/informationserver/Server/DSEngine/bin/uv -admin -start
    /mnt/efs/opt/ibm/informationserver/ASBNode/bin/NodeAgents.sh start
    aws cloudwatch enable-alarm-actions --alarm-names etl-$SUBENV-engine-health
else [[ $(hostname) == *"srv"* ]]; then
    su wasadm -c "cd /opt/IBM/WebSphere/AppServer/profiles/DmgrSrv01/bin; ./stopManager.sh; cd /opt/IBM/WebSphere/AppServer/profiles/AppSrv01/bin; ./stopServer.sh server1; ./stopNode.sh"
    /tescobank/scripts/01_start_all_service.sh
    aws cloudwatch enable-alarm-actions --alarm-names etl-$SUBENV-service-health
fi

echo "Turning off maintenance mode.."
# Turning off maintenance mode
/opt/ibm/informationserver/ASBNode/bin/SessionAdmin.sh -url https://$SRV_HOST:9443 -user isadmin -password $DS_PASSWORD -set-maint-mode OFF

# Removing comment from monitor script
sed -i '/.*monitor.sh.*/ s/^#*//' /var/spool/cron/root

echo "-----------------------------------------------"
echo "Script ended at $(date)"
echo "-----------------------------------------------"
