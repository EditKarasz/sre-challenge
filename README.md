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
```$ grep 'image:' sre-challenge/invoice-app/deployment.yaml
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

As a first implementation I have added an ingress controller.
It creates the ingress controller and connects to a service created for the invoice-app deployment.  
Deploying the service:
```
$ cd sre-challenge/invoice-app/
$ kubectl apply -f ingress.yaml
```

In minikube it is easy to get the url:
```
$ minikube service invoice-app-backend --url
```

You have to end it with: **/invoices**

Under not minikube / from kubectl command lines it is a combination of the ingress' IP (this is the externally available Ngnix service). You can get it from:
```
$ kubectl get ingress
```
Here you can choose the address.

To get the IP run: 
```
$ kubectl get service invoice-app-backend
```
The port is the second port number.

The url will be: **http://<INGRESS_ADDRESS>:<SERVICE_TARGET_IP>/invoices**

2. `payment-provider` must be only reachable from inside the cluster.
3. Update existing `deployment.yaml` files to follow k8s best practices. Feel free to remove existing files, recreate them, and/or introduce different technologies. Follow best practices for any other resources you decide to create.
4. Provide a better way to pass the URL in `invoice-app/main.go` - it's hardcoded at the moment
5. Complete `deploy.sh` in order to automate all the steps needed to have both apps running in a K8s cluster.
6. Complete `test.sh` so we can validate your solution can successfully pay all the unpaid invoices and return a list of all the paid invoices.

### Part 3 - Questions

Feel free to express your thoughts and share your experiences with real-world examples you worked with in the past.

This is added inline in the README.md for each commit. As I progress I add my comments and thoughts to the documentation. I will might change the solutions because I try to finish the task and improve it if I have remaining time.

#### Requirements

1. What would you do to improve this setup and make it "production ready"?

I would add a build step and a deploy step so I would cut the Docker container into half. This would be easier if I have a solution that can be shared with github project.

2. There are 2 microservices that are maintained by 2 different teams. Each team should have access only to their service inside the cluster. How would you approach this?

I would use RBAC aaccess control model. It can be implemented with a Role on a namespace level. On Google Cloud Platform Google users and groups are integrated to the Kubernetes system. I worked on a solution which used Active Directory / LDAP for authentication and authorisation. 

3. How would you prevent other services running in the cluster to communicate to `payment-provider`?

The build in option is to set up Network Policies. You can set up that there is no inbound traffic reaches the namespace. You can enable and block communication between pods. I think Ngnix also offers ingress options for network isolation but I don't know much about this.

## What matters to us?

We expect the solution to run but we also want to know how you work and what matters to you as an engineer.
Feel free to use any technology you want! You can create new files, refactor, rename, etc.

Ideally, we'd like to see your progression through commits, verbosity in your answers and all requirements met.
Don't forget to update the README.md to explain your thought process.
