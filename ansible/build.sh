#!/bin/bash

set -euf -o pipefail

usage() {
  echo "usage: $0 tag-target env [region] [ami] [type]"
  exit 1
}

[[ -z ${1:-''} ]] && usage
[[ -z ${2:-''} ]] && usage

REGION='us-west-2'
TARGET="$1"
TARGETENV="$2"
EXTREGION=''
EXTAMI=''
EXTTYPE=''
export ANSIBLE_HOST_KEY_CHECKING=no

[[ -n ${3:-''} ]] && REGION="$3"
[[ -n ${4:-''} ]] && EXTAMI="-e ec2_ami='$4'"
[[ -n ${5:-''} ]] && EXTTYPE="-e ec2_type='$5'"

export REGION
EXTREGION="-e ec2_region=${REGION}"

declare -a commands=(
  './inventory/ec2.py --refresh-cache >/dev/null'
  "ansible-playbook --limit='${REGION}' -v -i inventory/ec2.py -t amicleaner -e amibuilder='$TARGET' -e env='$TARGETENV' $EXTREGION $EXTAMI build.yml || true"
  "ansible-playbook -v -i inventory/local -t amibuilder -e amibuilder='$TARGET' -e env='$TARGETENV' $EXTREGION $EXTAMI $EXTTYPE build.yml"
  './inventory/ec2.py --refresh-cache >/dev/null'
  "ansible-playbook --limit='${REGION}' -v -i inventory/ec2.py -t '$TARGET' site.yml"
  "ansible-playbook --limit='${REGION}' -v -i inventory/ec2.py -t amiimager -e amibuilder='$TARGET' -e env='$TARGETENV' $EXTREGION $EXTAMI build.yml"
  "ansible-playbook --limit='${REGION}' -v -i inventory/ec2.py -t amicleaner -e amibuilder='$TARGET' -e env='$TARGETENV' $EXTREGION $EXTAMI build.yml"
)

for command in "${commands[@]}" ; do
  echo "==> $command"
  eval $command
done
