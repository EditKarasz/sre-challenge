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

I have used MiniKube on my local computer. It needs to connect to an external container registry.
```$ minikube addons configure registry-creds```

I have added my dockerhub account where I have pushed the built images. This meant I had to change the path to the image:
```
$ grep 'image:' sre-challenge/invoice-app/deployment.yaml
...
        image: karasze/payment-provider:latest
```

**Note:** Instead of the docker image tag latest I would create a version number and use it on all non development environments.

It is not possible to deploy the image from the deployment.yaml The image builds the application and run it as the default root user.
In the deployment.yaml we specify to run the application on a service user.

This is not really a bug but washing together the build and deployment steps. It is good to run the application as a non priviliged user. It is also
good to have a container where we install build tools and modules and in a separate container just the application itself.

The best solution would be to separate the steps into 2 by having a build Docker container and a deploy Docker container. If we use a build pipeline
1. we can build the application in the first step
2. if succeeds we can add a test steps
3. if succeeds we can create a deploy container and deploy it on the given environment

The fast solution is to allow the docker container to run as root on Kubernetes:
```
      securityContext:
        runAsNonRoot: false
```

After this the application was running but it hasn't displayed anything. I checked the pod logs and I find out that the port has been changed to 8081. To see anything displayed I have to add /invoice at the end of the URI.

#### Troubleshooting

Checking the health of the pods:
```
$ kubectl get pods
```

Unhealthy. Selecting one of the pods and check the status (at the end the latest logs):

```
$ kubectl describe pods <POD_NAME>
```

Checking the output logs of the container:
```
$ kubectl logs pods <POD_NAME>
```

### Part 2 - Setup the apps

We would like these 2 apps, `invoice-app` and `payment-provider`, to run in a K8s cluster and this is where you come in!

#### Requirements

1. `invoice-app` must be reachable from outside the cluster.

I have used a loadballancer. I have deployed the 2 applications on Minikube. On Minikube to expose the service on a external IP address you have to use minikube tunnel. To create it use:
```
$ minikube tunnel
```

**Note:** I have changed the kubernetes service configuration files to templates. These are not valid service configurations anymore. To create the loadbalancer use the deploy.sh script.

You can verify that it is created properly use:
```
$ kubectl get services --namespace payment-services

```

The external url will be: **http:/<EXTERNAL_IP>:8081**
To check it works you should check the GET endpoint: **http:/<EXTERNAL_IP>/invoices**

The external url will be: **http:/<EXTERNAL_IP>:8081**
To check it works you should check the GET endpoint: ***http:/<EXTERNAL_IP>:8081/invoices***
2. `payment-provider` must be only reachable from inside the cluster.
**Note:** You can troubleshoot the application by [port forwarding](https://kubernetes.io/docs/tasks/access-application-cluster/port-forward-access-application-cluster/) to your local host. 
3. Update existing `deployment.yaml` files to follow k8s best practices. Feel free to remove existing files, recreate them, and/or introduce different technologies. Follow best practices for any other resources you decide to create.
- I have added labels. It will be good for grouping if we expand the services in the future. I use the labels for the kubectl queries.
- I have created a service for each application for management reasons. invoice-app's service is a loadbalancer. This means a network layout is assinged to it. The payment-provider has a simple service for magement reason.
- I have added resources to the containers / pods. In this excercise it is not important but when we plan how much resources we need to size the cluster which host multiple applications and/or environments it is useful. Resource requests and limits determines if an application can be deployed on the cluster and which node has enough resources available to host a new pod. The LimitRange works on namespace level but if we have gotten a complex service with multiple applications, and these applications have different resource needs I would specify directly the resources in the deployment. See commented lines in the deployment.yaml
- This is not important but I have updated the rollout strategy. It is not important because we do not talk about releases in this exercise. It is a ramped (slow) rollout. The new release creates a new replica set. One new pod spins up at the time and one stops from the original replica set. Replaces one at the time.
- This is not important because if we use kubectl for deployment it can run all the files located in a folder but I have moved every yaml file in one configuration as code file.
**Note**: It is suggested to have one kubernetes service configuration file / service. I haven't done that because in the deploy.sh script I use yq to update the environment variables. qy creates the key does not exist in the attribute hierarcy. In our example it created container attribute in the service.
4. Provide a better way to pass the URL in `invoice-app/main.go` - it's hardcoded at the moment
I have created an environment variable PAYMENT_URL. I get it from the Docker container. It is possibe to update the url at build time. The best would have been if I can update the variable in run time. I don't have a clear view how to do this. Maybe a configmap is the right place to pass this parameter to the containers at the time these spined up.
**Note:** This was the task when I realised that the 2 applications are connected. I have moved them into the same namespace.

5. Complete `deploy.sh` in order to automate all the steps needed to have both apps running in a K8s cluster.

**Note:** I use jq for querying service attributes. You have to install it on your deployment enviroment.

I have created a similar deployment as a demo we have done at Etraveli. It is using the service configurations as code with kubectl. We update the yaml templates according the environment we want to build with variable replacement. As a next step it is possible to create custom Helm charts for each service. I would (if I have time I will) rewrite the whole deployment to use [Kustomize](https://kustomize.io/). Currently I use Kustomize because you can keep your configuration as code small by only listing the attributes / settings which are necessary to describe the services.

I created kubernetes service configuration templates out from the existing yaml files. The deployment file customise it / service. I have added comments inline the code.
**Note**: yq is a prerequirement for the deploy.sh script.

6. Complete `test.sh` so we can validate your solution can successfully pay all the unpaid invoices and return a list of all the paid invoices.

**Note:** I have tested the deployment steps and that the services are up to date in deployment time. As an extra step I would set up service monitoring. I have experie'ce with the Prometheus, Loki, Grafana observibility tools on Kubernetes.


### Part 3 - Questions

Feel free to express your thoughts and share your experiences with real-world examples you worked with in the past.

This is added inline in the README.md for each commit. As I progress I add my comments and thoughts to the documentation. I will might change the solutions because I try to finish the task and improve it if I have remaining time.

#### Requirements

1. What would you do to improve this setup and make it "production ready"?

- Regarding the Docker containers: I would add a build step and a deploy step so I would cut the Docker container into half. This would be easier if I have a solution that can be shared with github project.
- I would create multiple environments. At least stage and prod. These environments can be on the same cluster within different projects with the same namespaces. We can create multiple namespaces for each enviroment, we can have multiple clusters for each environments... etc. There are many designs available.
- I would add a build and a deploy pipeline. The build pipeline would have code quality checks, syntax checks. If there is a codebase the unittest would be added here. The deploy pipeline would deploy to multiple environments. On each environment it would run an integartion test on the top. Each environmnet would be dependent on the other's success. For example: stage build would only start if dev deployment succeeds. Dev deployment would be dependent on a successfull dev build.

2. There are 2 microservices that are maintained by 2 different teams. Each team should have access only to their service inside the cluster. How would you approach this?

I would use RBAC aaccess control model.  On Google Cloud Platform Google users and groups are integrated to the Kubernetes system. I worked on a solution which used Active Directory / LDAP for authentication and authorisation. 

**Note:** Because the two services are dependent on each other I cannot give a better solution for this ATM. The payment-provider is only reachable inside the the cluster. I have moved the 2 apps into the same namespace. The suggestion to separate the teams with a Role which is namespace specific does work anymore. We can set up RoleBindigs for the teams...

3. How would you prevent other services running in the cluster to communicate to `payment-provider`?

The built in Kubernetes option is to set up Network Policies. You can set up that there is no inbound traffic reaches the namespace. You can enable and block communication between pods. I think Ngnix also offers ingress options for network isolation but I don't know much about this.

## What matters to us?

We expect the solution to run but we also want to know how you work and what matters to you as an engineer.
Feel free to use any technology you want! You can create new files, refactor, rename, etc.

Ideally, we'd like to see your progression through commits, verbosity in your answers and all requirements met.
Don't forget to update the README.md to explain your thought process.
