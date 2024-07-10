```markdown
# Thumbnail Generator CI/CD and Kubernetes Deployment

## Overview

This project implements a CI/CD pipeline and Kubernetes deployment for a Thumbnail Generator application using Google Cloud Platform (GCP) services. The system is designed to automatically build, test, and deploy the application whenever changes are pushed to the GitHub repository.

## Architecture

- Version Control: GitHub
- CI/CD: Google Cloud Build
- Container Registry: Google Artifact Registry
- Kubernetes Cluster: Google Kubernetes Engine (GKE)
- Object Storage: MinIO (simulating S3-compatible storage)
- Database: MongoDB

The application is deployed to GKE with the following configuration:

- Cluster Name: cogent-cloudbuild
- Zone: us-central1-c
- Artifact Registry: us-central1-docker.pkg.dev/cogent-426809/cogent-repository/cogent-assignment


## Kubernetes Deployment

The application is deployed to Kubernetes using a deployment file (`k8s-deployment.yaml`) that defines the following resources:

1. Secret: `minio-credentials` for storing MinIO access and secret keys.

2. Deployment: `thumbnail-generator`
   - 2 replicas
   - Uses the latest image from the Artifact Registry
   - Sets environment variables for MongoDB and MinIO connections
   - Defines resource requests and limits
   - Includes readiness and liveness probes

3. Service: `thumbnail-generator-service`
   - Type: LoadBalancer
   - Exposes port 80, targeting container port 3000

4. Deployment: `thumbnail-generator-worker`
   - 2 replicas
   - Runs the worker process using `node dist/worker.js`
   - Shares the same image and most configurations with the main deployment

5. Deployment: `mongo`
   - Single replica for MongoDB

6. Service: `mongo-service`
   - Exposes MongoDB on port 27017

7. Deployment: `minio`
   - Single replica for MinIO
   - Uses official MinIO image

8. Service: `minio-service`
   - Exposes MinIO on port 9000

Key points of the deployment:

- The application is split into separate deployments for the API and worker processes, allowing independent scaling.
- MongoDB and MinIO are deployed within the cluster for simplicity, but in a production environment, managed services would be preferable.
- Resource requests and limits are set to ensure proper scheduling and prevent resource contention.
- Secrets are used to manage sensitive information like MinIO credentials.

To apply this deployment:

```bash
kubectl apply -f k8s-deployment.yaml
```

## CI/CD Pipeline

The CI/CD pipeline, defined in `cloudbuild.yaml`, includes a step to deploy to GKE using the `k8s-deployment.yaml` file:

```yaml
- name: 'gcr.io/cloud-builders/gke-deploy'
  args:
  - run
  - --filename=k8s-deployment.yaml
  - --image=us-central1-docker.pkg.dev/cogent-426809/cogent-repository/cogent-assignment:$COMMIT_SHA
  - --location=us-central1-c
  - --cluster=cogent-cloudbuild
```

This step updates the deployment with the newly built image, tagged with the commit SHA.

```

## Accessing the API

The application is accessible via the following LoadBalancer IP:

```
http://34.72.187.156
```
![image](https://github.com/royalket/cogent/assets/103560501/9c0ca835-ac30-4c77-a9ed-b64b97c22376)

## Testing the Deployment

I've conducted the following tests to verify the deployment:

1. Checking the API health:

```
$ curl http://34.72.187.156
{"data":"Hello from Thumbnail Generator"}
```

2. Uploading an image for thumbnail generation:

```
$ curl --location --request POST 'http://34.72.187.156/thumbnail' \
--form 'file=@"./test_image.jpg"'
{"data":{"job_id":"130881b9-05fe-48c8-b36d-acdd9903a3f6"}}
```

3. Checking the job status:

```
$ curl --location --request GET 'http://34.72.187.156/thumbnail/130881b9-05fe-48c8-b36d-acdd9903a3f6'
{"data":{"_id":"130881b9-05fe-48c8-b36d-acdd9903a3f6","filename":"130881b9-05fe-48c8-b36d-acdd9903a3f6.jpg","originalFilename":"test_image.jpg","status":"waiting","thumbnailFilename":"","thumbnailLink":""}}
```

## Deployment Instructions

1. Set up a GCP project and enable necessary APIs (Compute Engine, Kubernetes Engine, Cloud Build, Artifact Registry).

2. Create a GKE cluster:
   ```
   gcloud container clusters create cogent-cloudbuild --zone us-central1-c
   ```

3. Set up a Cloud Build trigger connected to the GitHub repository.

4. Create an Artifact Registry repository:
   ```
   gcloud artifacts repositories create cogent-repository --repository-format=docker --location=us-central1
   ```

5. Update the `cloudbuild.yaml` & `deployments.yaml` file with the project-specific details.

6. Push changes to the GitHub repository to trigger the CI/CD pipeline.

7. Once deployed, access the application using the LoadBalancer IP:
   ```
   kubectl get services thumbnail-generator-service
   ```

## CI/CD Pipeline

The CI/CD pipeline is defined in the `cloudbuild.yaml` file and includes the following steps:

1. Install dependencies
2. Build the TypeScript project
3. Build the Docker image
4. Push the Docker image to the Artifact Registry
5. Deploy to GKE

## Dockerfile

The Dockerfile has been slightly modified for this deployment:

```dockerfile
FROM node:14.18.2-bullseye-slim
RUN mkdir /cogentapp
COPY . /cogentapp
WORKDIR /cogentapp
RUN npm install
RUN npm run build
EXPOSE 3000
CMD [ "npm", "start" ]
```


The application is split into two main components:
1. API Server: Handles incoming requests and job creation
2. Worker: Processes thumbnail generation jobs

Both components share the same codebase but are deployed as separate containers for scalability.

## Technology Choices and Trade-offs

1. GCP Services: Chosen for their seamless integration and managed infrastructure, reducing operational overhead. Trade-off: Potential vendor lock-in.

2. Kubernetes: Provides scalability and container orchestration. Trade-off: Increased complexity compared to simpler deployment options.

3. MinIO: Used as an S3-compatible storage solution. In production, this could be replaced with GCS for better integration with GCP. Trade-off: Additional component to manage in the development environment.

4. MongoDB: Chosen for its flexibility and ease of use. Trade-off: May require more management compared to managed database services.

## Disaster Recovery

1. Ensure all code is committed to the GitHub repository.
2. Recreate the GKE cluster if necessary.
3. Re-run the Cloud Build pipeline to redeploy the application.
4. Restore any necessary data from backups (MongoDB data, MinIO objects).

## Potential Improvements

1. Autoscaling: Implement Horizontal Pod Autoscaler (HPA) for the API and worker deployments. Configure based on CPU utilization or custom metrics.

   ```yaml
   apiVersion: autoscaling/v2beta1
   kind: HorizontalPodAutoscaler
   metadata:
     name: thumbnail-generator-hpa
   spec:
     scaleTargetRef:
       apiVersion: apps/v1
       kind: Deployment
       name: thumbnail-generator
     minReplicas: 2
     maxReplicas: 10
     metrics:
     - type: Resource
       resource:
         name: cpu
         targetAverageUtilization: 70
   ```

2. Cost Monitoring: Utilize GCP's Cost Management tools to analyze and monitor cluster costs. Set up budget alerts and use GKE usage metering for more granular cost tracking.

3. Data Backups: 
   - For MongoDB: Set up periodic snapshots or use a tool like mongodump for regular backups.
   - For MinIO: Implement periodic syncs to a GCS bucket for redundancy.

4. Security Enhancements:
   - Implement network policies to restrict pod-to-pod communication.
   - Use Secrets management solutions like HashiCorp Vault or GCP Secret Manager for sensitive data.

5. Monitoring and Logging:
   - We can set up Prometheus and Grafana for monitoring.
   - Implement structured logging and use GCP's Cloud Logging for centralized log management.

6. CI/CD Improvements:
   - Implement canary deployments or blue-green deployments for safer releases.
   - Add more comprehensive test coverage, including integration and end-to-end tests.

7. Infrastructure as Code:
   - Use Terraform or Pulumi to manage GCP resources, ensuring reproducibility and version control of infrastructure.

8. Service Mesh:
   - Consider implementing Istio for advanced traffic management, security, and observability features.

## Conclusion

This deployment provides a solid foundation for running the Thumbnail Generator application in a scalable and maintainable way. By leveraging GCP services and Kubernetes, we've created a system that can easily scale to meet demand and be extended with additional features and improvements as needed.
```
