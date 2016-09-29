#!/bin/bash

arrayContains () {
    local array="$1[@]"
    local seeking=$2
    local index=-1
    for element in "${!array}"; do
        index=$((index + 1))
        if [[ $element == $seeking ]]; then
            echo $index
            return
        fi
    done
    echo -1
}

check () {
  retval=$1
  if [ $retval -ne 0 ]; then
      >&2 echo "Return code was not zero but $retval"
      exit 999
  fi
}

imageNameExists () {
  if [[ $imageName == "" ]]; then
    >&2 echo "Missing image name. Use --image to provide an image name."
    exit 4
  fi
}

killExistingSsh () {
  existingSshPid=$(pgrep ssh)
  if [[ $existingSshPid != "" ]]; then
    echo "Killing existing ssh."
    kill -9 $existingSshPid
    check $?
  fi
}

makeVars () {
    local name="$1[@]"
    local seeking=$2
    local index=-1
    local array=("${!name}")
    for element in "${array[@]}"; do
        index=$((index + 1))
        if [[ $element == $seeking ]]; then
          environmentVar=${array[$(($index + 1))]}
          if [[ $environmentVar == --* ]]; then
            >&2 echo "You must supply a valid value to --env."
            exit 15
          fi
          echo $environmentVar
        fi
    done
}

exportEnvs () {
    local name="$1[@]"
    for element in ${!name}; do
      IFS='=' read -a values <<< "$element"
      variableName=${values[0]}
      variableValue=${values[1]}
      if [ -z $variableValue ]; then
        >&2 echo "You must supply a valid value to the enviornment variables."
        exit 14
      fi
      echo "Exporting $variableName"
      export $variableName=$variableValue
    done
}


version=$(date +%Y-%m-%d_%H-%M-%S)
versionFileName=imageVersion.txt
versionFile=$(pwd)/$versionFileName

args=("$@")

#export variables defined with -e:
echo "Exporting variables supplied as arguments..."
envs=$(makeVars args '-e')
exportEnvs envs
echo "Variables exported."

envIndex=$(arrayContains args "--env")
if [ $envIndex -gt -1 ]; then
  env=${args[$(($envIndex + 1))]}
  if [[ $env == --* ]]; then
    >&2 echo "You must supply a valid value to --env."
    exit 5
  fi
else
  env='Debug'
fi

defaultenvIndex=$(arrayContains args "--defaultenv")
if [ $defaultenvIndex -gt -1 ]; then
  defaultenv=${args[$(($defaultenvIndex + 1))]}
  if [[ $defaultenv == --* ]]; then
    >&2 echo "You must supply a valid value to --defaultenv."
    exit 5
  fi
else
  defaultenv='Debug'
fi

imageIndex=$(arrayContains args "--image")
if [ $imageIndex -gt -1 ]; then
  imageName=${args[$(($imageIndex + 1))]}
  if [[ $imageName == --* ]]; then
    >&2 echo "You must supply a valid value to --image."
    exit 6
  fi
fi

sshServerIndex=$(arrayContains args "--server")
if [ $sshServerIndex -gt -1 ]; then
  sshServer=${args[$(($sshServerIndex + 1))]}
  if [[ $sshServer == --* ]]; then
    >&2 echo "You must supply a valid value to --server"
    exit 7
  fi
fi

sshPortIndex=$(arrayContains args "--port")
if [ $sshPortIndex -gt -1 ]; then
  sshPort=${args[$(($sshPortIndex + 1))]}
  if [[ $sshPort == --* ]]; then
    >&2 echo "You must supply a valid value to --port"
    exit 8
  fi
fi

sshUserIndex=$(arrayContains args "--user")
if [ $sshUserIndex -gt -1 ]; then
  sshUser=${args[$(($sshUserIndex + 1))]}
  if [[ $sshUser == --* ]]; then
    >&2 echo "You must supply a valid value to --user"
    exit 9
  fi
fi

projectNameIndex=$(arrayContains args "--project")
if [ $projectNameIndex -gt -1 ]; then
  projectName=${args[$(($projectNameIndex + 1))]}
  if [[ $projectName == --* ]]; then
    >&2 echo "You must supply a valid value to --project"
    exit 12
  fi
fi

sshKeyIndex=$(arrayContains args "--key")
if [ $sshKeyIndex -gt -1 ]; then
  sshKey=${args[$(($sshKeyIndex + 1))]}
  if ! [[ $sshKey =~ ^'-----BEGIN RSA PRIVATE KEY-----\n'.*'\n-----END RSA PRIVATE KEY-----'$ ]]; then
    >&2 echo -e "You must supply a valid value to --key. Value supplied (first 20 characters):\n${sshKey:0:20}"
    exit 13
  fi
fi

buildIndex=$(arrayContains args "--build")
if [ $buildIndex -gt -1 ]; then
  # get the context
  contextIndex=$(arrayContains args "--context")
  if [ $contextIndex -gt -1 ]; then
    context=${args[$(($contextIndex + 1))]}
    if [[ $context == --* ]]; then
      >&2 echo "You must supply a valid value to --context"
      exit 16
    fi
  else
    context='.'
  fi
  imageNameExists
  if [ $env == $defaultenv ]; then
    dockerFileName="Dockerfile"
  else
    dockerFileName="Dockerfile.$env"
  fi
  if [ -f $dockerFileName ]; then
    echo "Building the image $imageName ($env)."
    docker build -f $dockerFileName -t "$imageName:$version" $context
    check $?
    docker tag "$imageName:$version" "$imageName:latest"
    check $?
    echo $version > $versionFile
    exit 0
  else
    >&2 echo "$env is not a valid parameter. File '$dockerFileName' does not exist."
    exit 1
  fi
  exit 0
fi

composeIndex=$(arrayContains args "--compose")
if [ $composeIndex -gt -1 ]; then
  if [ $env == $defaultenv ]; then
    composeFileName="docker-compose.yml"
  else
    composeFileName="docker-compose.$env.yml"
  fi
  if [ -f $composeFileName ]; then
    if [[ ( ! ( $sshServer == "" && $sshPort == "" && $sshUser == "" && $sshKey == "" )) && ( ! ( $sshServer != "" && $sshPort != "" && $sshUser != "" && $sshKey != "" )) ]]; then
      >&2 echo "You must supply all options --server, --port, --user and --key or none of them."
      exit 10
    fi
    if [[ $sshServer != "" ]]; then
      echo "Connecting to $sshServer:$sshPort with user $sshUser..."
      killExistingSsh
      keyFile=$(tempfile)
      echo -e $sshKey > $keyFile
      ssh $sshUser@$sshServer -L 2375:localhost:2375 -p $sshPort -oStrictHostKeyChecking=no -i $keyFile -N &
      sshPid=$!
      export DOCKER_HOST=tcp://localhost:2375
      connectExitCode=1
      tries=0
      while [ $connectExitCode -ne 0 ]; do
        tries=$((tries+1))
        if [ $tries -gt 5 ]; then
          >&2 echo "Could not connect to server, exiting..."
          killExistingSsh
          exit 11
        fi
        echo "Testing if port 2375 is open..."
        timeout 1 bash -c "cat < /dev/null > /dev/tcp/localhost/2375"
        connectExitCode=$?
        if [ $connectExitCode != "0" ]; then
          sleep 1
        fi
      done
    fi
    echo "Searching for image version file $versionFile..."
    if [ ! -f $versionFile ]; then
      echo "Could not find $versionFile, searching for $versionFileName..."
      versionFile=$(find . -name $versionFileName)
    fi
    if [ ! -z "$versionFile" ] &&  [ -f $versionFile ]; then
      echo "Found $versionFile."
      export IMAGE_VERSION=$(cat $versionFile)
    else
      echo "Found $versionFile, using default value 'lastest'."
      export IMAGE_VERSION="latest"
    fi
    echo "Version is '$IMAGE_VERSION'."
    echo "Running compose file $composeFileName ($env)."
    echo "Removing previous environment..."
    if [[ $projectName == "" ]]; then
      projectName=$(echo ${PWD##*/} | tr '[:upper:]' '[:lower:]')
    fi
    docker-compose -f $composeFileName -p $projectName down
    check $?
    echo "Creating new environment..."
    docker-compose -f $composeFileName -p $projectName up -d
    exitCode=$?
    if [[ $sshServer != "" ]]; then
      echo "Killing SSH connection..."
      kill -9 $sshPid
      rm $keyFile
    fi
    check $exitCode
    exit 0
  else
    >&2 echo "$env may not be a valid parameter. File '$composeFileName' does not exist."
    exit 2
  fi
  exit 0
fi

cleanIndex=$(arrayContains args "--clean")
if [ $cleanIndex -gt -1 ]; then
  imageNameExists
  if [ $env == $defaultenv ]; then
    composeFileName="docker-compose.yml"
  else
    composeFileName="docker-compose.$env.yml"
  fi
  if [ -f $composeFileName ]; then
    echo "Killing with compose file $composeFileName ($env)."
    docker-compose -f $composeFileName down
    check $?
  else
    >&2 echo "$env may not be a valid parameter. File '$composeFileName' does not exist."
    exit 6
  fi
  containerIds=$(docker ps | tail -n +2 | grep -w "$imageName" | cut -f1 -d ' ')
  for containerId in $containerIds; do
    docker rm -f $containerId
    check $?
  done
  exit 0
fi

pushIndex=$(arrayContains args "--push")
if [ $pushIndex -gt -1 ]; then
  imageNameExists
  if [ -f $versionFile ]; then
    version=`cat $versionFile`
    echo "Pushing the image $imageName with version $version."
    docker push "$imageName:$version"
    check $?
    docker push "$imageName:latest"
    check $?
    exit 0
  else
    >&2 echo "File '$versionFile' does not exist."
    exit 3
  fi
  exit 0
fi

helpIndex=$(arrayContains args "--help")
if [ $helpIndex -gt -1 ]; then
  echo "
Usage:
  ./dockerTask.sh --clean --image <IMAGE_NAME> [--env (Debug|Release)] [--defaultenv (Debug|Release)]
  ./dockerTask.sh --build --image <IMAGE_NAME> [--env (Debug|Release)] [--defaultenv (Debug|Release)] [--context <BUILD_CONTEXT>]
  ./dockerTask.sh --compose [--server <SSH_SERVER> --port <SSH_PORT> --user <SSH_USER> --key <SSH_KEY>] [--env (Debug|Release)] [--defaultenv (Debug|Release)] [ --project <DOCKER_COMPOSE_PROJECT_NAME> ]
  ./dockerTask.sh --push --image <IMAGE_NAME>
  ./dockerTask.sh --help"
  exit 0
fi
