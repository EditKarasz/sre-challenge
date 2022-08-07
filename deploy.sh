#!/bin/bash -e 

### The following parameters can come as arguments, environment variables, from a configuration file like an Ansible inventory

## The instance we deploy
instance='example'

## The release we deploy
version='1.0.0'
## I need this to be able to pull it from my private dockerhub repo
docker_repository='karasze/'


## A helper function to manage deployment failure
function error() {
  echo "DEPLOYMENT FAILED: $1" >> /dev/stderr
}

## A helper function to use yq from the script
function replace_value() {
  if [[ "${#}" == 3 ]]
  then
    ## In yq the value has to be double quited except if it is a boolean. We do not have booleans here.
    value="\"${2}\""
    yq eval "${1} = ${value}" -i "${3}" || error "yq failed to set value ${value} to attribute: ${1} in file ${3}"
  else
    error "yq needs 3 parameters: attribute location, value and file"
  fi
}



### yq is a prerequirement for this script
### Check if it is installed
yq -V || error "yq is not installed"

### We do not want to overwrite the existing files because we want them as template
rm -rf temp
mkdir temp || error "cannot create temporary directory: temp"

## The service prototype. Contains: invoice-app and payment-provider.
APPLICATIONS=( 'payment-provider' 'invoice-app' )

### Customise namespace from variables
cp namespace.yaml temp || error 'Failed to create namespace to temp'
replace_value .metadata.name "${application}" temp/namespace.yaml
replace_value .metadata.labels.instance "${instance}" temp/namespace.yaml

### Make sure that the namespace exists
#### kubectl apply creates it if does not exist
kubectl apply -f temp/namespace.yaml || error 'Failed to apply namespace config'

### Check if exists
#### kubectl exits with error if it does not exist
kubectl get namespaces --selector instance="${instance}"  || error 'Namespace does not exist'

### Apply LimitRange
kubectl apply -f limitrange.yaml --namespace="${application}" || error 'Failed to apply limitrange config'

## Check if exists
kubectl describe limits small --namespace="${application}" || error 'Limitrage does not exit'

for application in ${APPLICATIONS[@]}
do

  ### Customise namespace from variables
  cp namespace.yaml temp || error 'Failed to create namespace to temp'
  replace_value .metadata.name "${application}" temp/namespace.yaml
  replace_value .metadata.labels.instance "${instance}" temp/namespace.yaml

  ### Make sure that the namespace exists
  #### kubectl apply creates it if does not exist
  kubectl apply -f temp/namespace.yaml || error 'Failed to apply namespace config'

  ### Check if exists
  #### kubectl exits with error if it does not exist
  kubectl get namespaces --selector instance="${instance}"  || error 'Namespace does not exist'

  ### Apply LimitRange
  kubectl apply -f limitrange.yaml --namespace="${application}" || error 'Failed to apply limitrange config'

  ## Check if exists
  kubectl describe limits small --namespace="${application}" || error 'Limitrage does not exit'

  ## Customise application deployment file
  cp "${application}"/deployment.yaml temp || error "Failed to create ${application} deployment config"
  replace_value .metadata.labels.instance "${instance}" temp/deployment.yaml
  replace_value .spec.template.metadata.labels.instance "${instance}" temp/deployment.yaml
  replace_value .spec.selector.matchLabels.instance "${instance}" temp/deployment.yaml
  replace_value .spec.template.spec.containers[0].image "${docker_repository}${application}:${version}" temp/deployment.yaml
  

  ### Deploy the application
  kubectl apply -f temp/deployment.yaml --namespace="${application}" || error "Failed to apply ${application} config"

  ### Check if exists
  #### kubectl exits with error if it does not exist
  kubectl get deployment --namespace="${application}" --selector app="${application}"

  ### Customise application service
  ## We could have a dictionary instead of a list of applications and and add a port for each applications.
  ## In this case we can update the port variable here...
  cp "${application}"/service.yaml temp || error "Failed to create ${application} service config"
  replace_value .metadata.labels.instance "${instance}" temp/service.yaml
  replace_value .spec.selector.instance "${instance}" temp/service.yaml
  replace_value .metadata.labels.instance "${instance}" temp/service.yaml

  ### Deploy the service
  kubectl apply -f temp/service.yaml --namespace="${application}" || error "Failed to apply ${application} config"

  ### Check if exists
  #### kubectl exits with error if it does not exist
  kubectl get services --namespace="${application}" --selector app="${application}"


  ### Extra check for invoice-app because it should be available externally
  if [[ "${application}" == "invoice-app" ]]
  then
    ## Wait a minute for provisioning
    echo '1 minute break.' 
    sleep 60
    ## Collect EXTERNAL-IP:
    external_ip=$(kubectl get services --namespace="${application}" --selector app="${application}" -o yaml | yq  .items[0].status.loadBalancer.ingress.[0].ip)
    response_code=$(curl -o /dev/null --silent --head --write-out '%{http_code}\n' http://"${external_ip}":8081/invoices)
    ## I could have add a debug function to the code
    ## echo "http://${external_ip}:8081/invoices and ${response_code}"

    ## Test if it return 200
    if [[ ${response_code} == 200 ]]
     then
      echo 'Invoice-app up'
    fi
  fi
done

echo 'Successful deployment'

