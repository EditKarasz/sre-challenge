## Welcome
 
We're really happy that you're considering joining us!
This challenge will help us understand your skills and will also be a starting point for the next interview.
We're not expecting everything to be done perfectly as we value your time but the more you share with us, the more we get to know about you!
 
This challenge is split into 3 parts:
 
1. Debugging
2. Implementation
3. Questions
 
If you find possible improvements to be done to this challenge please let us know in this readme and/or during the interview.
 
## The challenge
 
Pleo runs most of its infrastructure in Kubernetes.
It's a bunch of microservices talking to each other and performing various tasks like verifying card transactions, moving money around, paying invoices, etc.
This challenge is similar but (a lot) smaller :D
 
In this repo, we provide you with:
 
- `invoice-app/`: An application that gets invoices from a DB, along with its minimal `deployment.yaml`
- `payment-provider/`: An application that pays invoices, along with its minimal `deployment.yaml`
- `Makefile`: A file to organize commands.
- `deploy.sh`: A file to script your solution
- `test.sh`: A file to perform tests against your solution.
 
### Set up the challenge env
 
1. Fork this repository
2. Create a new branch for you to work with.
3. Install any local K8s cluster (ex: Minikube) on your machine and document your setup so we can run your solution.
 
### Part 1 - Fix the issue
 
The setup we provide has a :bug:. Find it and fix it! You'll know you have fixed it when the state of the pods in the namespace looks similar to this:
 
```
NAME                                READY   STATUS                       RESTARTS   AGE
invoice-app-jklmno6789-44cd1        1/1     Ready                        0          10m
invoice-app-jklmno6789-67cd5        1/1     Ready                        0          10m
invoice-app-jklmno6789-12cd3        1/1     Ready                        0          10m
payment-provider-abcdef1234-23b21   1/1     Ready                        0          10m
payment-provider-abcdef1234-11b28   1/1     Ready                        0          10m
payment-provider-abcdef1234-1ab25   1/1     Ready                        0          10m
```
 
#### Requirements
 
The first step is to build an image called invoice-app and payment-provider.
 
I have used MiniKube on my local computer. It needs to connect to an external container registry. To connect to the one your docker user uses:
```$ minikube addons configure registry-creds```
 
I have added my docker hub account where I have pushed the images. This meant I had to change the path to the image. For example on the invoice-app:
```
$ grep 'image:' sre-challenge/invoice-app/deployment.yaml
...
       image: karasze/invoice-app:latest
```
 
It is not possible to deploy the image from the deployment.yaml The image builds the application and runs it as the default root user.
In the deployment.yaml we specify to run the application on a service user.
 
This is not really a bug but washing together the build and deployment steps. It is good to run the application as a non privileged user. It is also good to have a container where we install build tools and modules and the application itself is in a separate container.
 
The best solution would be to separate the steps into 2, by having a build Docker container and a deploy Docker container. If we use a build pipeline:
1. we can build the application in the first step
2. if succeeds we can add a tests (syntax, semantics, functionality with unit tests)
3. if succeeds we can create a deploy container and deploy it on the given environment
4. We can run integration tests
5. If it was dev or stage we kick off the next level of builds / deployments...
 
The fast solution is to allow the docker container to run as root on Kubernetes:
```
     securityContext:
       runAsNonRoot: false
```
but this is the default so we can remove it from the configuration.
 
 
After this the application is running but it hasn't displayed anything. I checked the pod logs and I found out that the port is not the default 8080. It has been changed to 8081. To test it you can submit a GET request which means to add /invoice at the end of the URI.
 
 
**Note:** I have defined the current setting as dev environment.
- I use the latest docker build not a versioned (released one)
- I build, test and deploy in the same step / container image
- I always pull the image and always restart it
 
These settings would have been removed / changed in a production environment.
 
#### Troubleshooting
 
Checking the health of the pods:
```
$ kubectl get pods
```
 
Unhealthy. Selecting one of the pods and check the status (at the end the latest logs):
```
$ kubectl describe pods <POD_NAME>
```
 
We can also check the output logs on the given container:
```
$ kubectl logs <POD_NAME>
```
 
- **Note**: This is useful to understand how the application is set up.
 
### Part 2 - Setup the apps
 
We would like these 2 apps, `invoice-app` and `payment-provider`, to run in a K8s cluster and this is where you come in!
 
#### Requirements
 
1. `invoice-app` must be reachable from outside the cluster.
 
I have used a load balancer. I have deployed the 2 applications on Minikube. On Minikube to expose the service on an external IP address you have to use the minikube tunnel. To create it run:
```
$ minikube tunnel
```
 
You can verify that it is deployed and created properly by kubectl command lines:
```
$ kubectl get services --namespace invoice-app
```
 
The external url will be: **http:/<EXTERNAL_IP>:8081**
To check it works you should check the GET endpoint: **http:/<EXTERNAL_IP>/invoices**
- **Note:** There will be another service which makes the payment-provider app endpoint available internally on the invoice-app namespace.
2. `payment-provider` must be only reachable from inside the cluster.
- **Note:** You can troubleshoot the application by [port forwarding](https://kubernetes.io/docs/tasks/access-application-cluster/port-forward-access-application-cluster/) to your local host. By default it is only available inside the cluster.
3. Update existing `deployment.yaml` files to follow k8s best practices. Feel free to remove existing files, recreate them, and/or introduce different technologies. Follow best practices for any other resources you decide to create.
- I have added labels. It will be good for grouping if we expand the services in the future. I use the labels for the kubectl queries too.
- I have created a service for each application for management reasons. invoice-app's service is a load balancer. This means a network layout is assigned to it. The payment-provider has a simple service for management reasons.
- I have created separate namespaces for each application. This is to separate the application and to set up separate RBAC access to them.
- Since I have learnt that the invoice app uses the payment-provider and the payment-provider does not have an externally exposed endpoint I have created a service which accesses the service internally, across namespaces.
- I have added resources to the containers / pods. In this exercise it is not important but when we plan how much resources we need to determine the size of the cluster, how many hosts we need for placement, how we will host multiple applications and/or environments it is useful. Resource requests and limits determine if an application can be deployed on the cluster and which node has enough resources available to host a new pod. The LimitRange works on namespace level but if we have got a complex service with multiple applications, and these applications have different resource needs I would specify directly the resources in the deployment.yaml file. See commented lines in the invoice-app/deployment.yaml
- This is not important but I have updated the rollout strategy. It is not important because we do not talk about releases in this exercise. It is a ramped (slow) rollout. The new release creates a new replica set. One new pod spins up at the time and one stops from the original replica set. Replaced one at the time.
- Kustomize will create us 1 configuration file for the whole required service deployment. (That is the suggested best practice.)
4. Provide a better way to pass the URL in `invoice-app/main.go` - it's hard coded at the moment
- I have created an environment variable PAYMENT_URL. I get it from the Docker container. It is possible to update the url at build time. The best would have been if I can update the variable in run time. ATM I don't have a clear view how to do this. Maybe a configmap is the right place to pass this parameter to the containers at the time these spined up. The url is a constant in the Kubernetes service so it does not have to be updated at each build.
- **Note:** This was the task when I realised that the 2 applications are connected.
 
5. Complete `deploy.sh` in order to automate all the steps needed to have both apps running in a K8s cluster.
 
- I have not used make at all during this exercise. We have to invoke 1 command line to deploy the services. make can invoke a command line too.
 
- I have changed the default deployment strategy to use Kustomize. It does not need a deploy.sh. `kubectl apply -f ./base` should be able to deploy the kustomise project. If you want to generate the yaml configuration files for verification then [install Kustomize](https://kubectl.docs.kubernetes.io/installation/kustomize/). To see the output run: `kustomize build`. You can use the 2 command lines together like: `kustomize build ./base | kubectl apply -f -` If you want to keep kubectl and kustomize’s version separate this will the right way to do.
 
- **Note:** Some of the Kustomize versions have been released with bugs. You might have to install a different version from the one on your computer to successfully generate the service configuration files. I was able to generate a proper output with Kustomize version 4.5.7.
 
6. Complete `test.sh` so we can validate your solution can successfully pay all the unpaid invoices and return a list of all the paid invoices.
- I could implement this however I don't like the solution which I have come up with. The testing itself is `invoice-app/test/test.py`. test.sh executes the testing externally, on your localhost with kubectl command lines. These are my considerations:
- **Pre Requirements**: You need to install **yq** on the host where you run the `test.sh` from. I use it in one of the kubectl queries.
- I used Python3 because of the `requests` module.
- The payment app is only internally available. I have not found a good solution to run it at the right place. I run it inside the `invoice-app` namespace. I can run scripts with a command line if it is available internally on the container image. So I stored the script on the image and I installed `python3` on it in build time. Than I can execute the script from one of the pods: `kubectl exec --stdin --tty invoice-app-5cdd4bd6d9-8zqq5 --namespace invoice-app -- test/python3`. - I would only use this in a non-prod environment.
- The applications are not documented. I reverse engineered it but in real life I would not do this but ask the developers to provide information. The payment url is from the invoice-app's namespace is **http://payment-provider.payment-provider.svc.cluster.local:8082/payment/pay** The data is 1 invoice form **http:/<EXTERNAL_IP>/invoices** list minus the InPaid attribute. It is:
```
{
InvoiceId: XXX,
Value: YYY,
Currency: ZZZ
}
```
- I would not write a functionality test which changes the status of the deployed service data. I would ask the developers to provide unit tests attached to the code. They could create a mock test for their service so they don't need to deploy it. I would write integration tests to check the functionalities but not to change any of the default data on the service. I would create and remove my uploaded data.
 
### Part 3 - Questions
 
Feel free to express your thoughts and share your experiences with real-world examples you worked with in the past.
 
- This is added inline in the README.md for each commit. As I progress I add my comments and thoughts to the documentation. I might change the solutions because I will try to finish the task and improve it if I have remaining time.
 
#### Requirements
 
1. What would you do to improve this setup and make it "production ready"?
 
- Regarding the Docker containers: I would add a build step, a test step and a deploy step so I would cut the Docker container into 3 parts. The dev container would contain the source code and deployment tools. We would build the service. It can run as root user. If we take the example of my current implementation for testing, I would need a testing container which has Python 3, pip requirements and the test scripts available next to the build code. The prod container would only contain the minimal settings which are required to run the build service code. This should be versioned not and the Docker pull, service restart configurations should be reverted in the deployment.yaml.
- I would create multiple environments for the services. At least stage and prod. These environments can be on the same cluster within different projects with the same namespaces. We can create multiple namespaces for each environment / tag the namespaces with the environment prefix, we can have multiple clusters for each environment... etc. There are many designs available.
- I would add a build and a deploy pipeline. The build pipeline would have code quality checks, syntax checks. If there is a codebase the unittest would be added here. The deploy pipeline would deploy to multiple environments. In each environment it would run an integration test on the top. Each environment would be dependent on the other's success. For example: stage build would only start if dev deployment succeeds. Dev deployment would be dependent on a successful dev build.  Maybe we can set up and share a cicd pipeline with Github but I have not experimented with this yet.
- As an extra step I would set up service monitoring. I have experience with the Prometheus, Loki, Grafana observibility tools on Kubernetes.
- If we run it on a commercially available cloud service I would set up cost monitoring too.
- I would use disks to store the database data on it. I would set up regular backups.
 
2. There are 2 microservices that are maintained by 2 different teams. Each team should have access only to their service inside the cluster. How would you approach this?
 
- I would use the RBAC access control model. On Google Cloud Platform Google users and groups are integrated to the Kubernetes system. I worked on a solution which used Active Directory / LDAP for authentication and authorisation.
 
3. How would you prevent other services running in the cluster from communicating to `payment-provider`?
 
- The built-in Kubernetes option is to set up Network Policies. You can set up that there is no inbound traffic reaching the namespace. You can enable and block communication between pods. I think Ngnix also offers ingress options for network isolation but I don't know much about this. You probably use Istio to set up, manage and monitor this.
 
## What matters to us?
 
We expect the solution to run but we also want to know how you work and what matters to you as an engineer.
Feel free to use any technology you want! You can create new files, refactor, rename, etc.
 
Ideally, we'd like to see your progression through commits, verbosity in your answers and all requirements met.
Don't forget to update the README.md to explain your thought process.
