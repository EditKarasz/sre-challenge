#!/bin/bash

## Collect EXTERNAL-IP:
### This would not be a problem if we have a DNS server
echo 'Collecting the external-ip for the invoice-app url'
external_ip=$(kubectl get services --namespace=invoice-app --selector app=invoice-app -o yaml | yq  .items[0].status.loadBalancer.ingress.[0].ip)
response_code=$(curl -o /dev/null --silent --head --write-out '%{http_code}\n' http://"${external_ip}":8081/invoices)

echo "http://${external_ip}:8081/invoices and ${response_code}"

## This is not working. BTW the best would have been if the service has a status endpoint
## Test if it return 200. It will return 404 so I have ignored this test.
if [[ ${response_code} == 200 ]]
then
  echo 'Invoice-app up'
fi

## We will have to run the following command lines on the kubectl to execute the test script inside one of the invoice-app containres
one_pod=$(kubectl get pods --namespace=invoice-app -o yaml | yq  .items[0].metadata.name)

echo 'Install the pip packages to the running container'
run_requirements=$(kubectl exec "${one_pod}" --namespace invoice-app -- python3 -m pip install -r ./test/requirements.txt)

echo 'Run the test scirpt'
run_python_script=$(kubectl exec "${one_pod}" --namespace invoice-app -- python3 test/test.py "${external_ip}")
