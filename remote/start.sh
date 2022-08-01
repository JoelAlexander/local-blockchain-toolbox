#!/bin/bash
scriptPath=$(dirname $(realpath $0))

if [ -z $1 ]
then
  echo "hostname or ip required" && exit 1
fi

$scriptPath/install.sh $1 &&\
ssh ubuntu@$1 './host/install.sh' &&\
echo "To complete setup and start the blockchain, run the command: './host/setup.sh && ./host/start.sh'" &&\
ssh ubuntu@$1
# TODO: Must run setup.sh not over ssh because node requires loading of the .profile
# to be on the path.  Maybe there's a way around this.
