# Epoch Time API Deployment

This project set up AWS infrastructure to deploy a simple Go application returning the current epoch time as a JSON response.

## Prerequisites

- Install [Terraform](https://www.terraform.io/downloads.html)
- Configure AWS CLI and authenticate with your AWS account. See [Configuring the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html).
- Docker installed on your machine for building the container image.

### Versions Used

This project has been tested with the following versions:

- Terraform `v1.5.7`
- AWS Provider for Terraform `v5.25.0`

## Building the Docker Image

1. Run the following command to build the image:

```sh
docker build -t <container registry>/epoch-time:latest .
```

2. Push the image to Docker Hub:

```sh
docker push <container registry>/epoch-time:latest
```

## Updating the Terraform Script

Replace the image with `<container registry>/epoch-time:latest` in the `aws_ecs_task_definition` resource in the Terraform script.

## Deploying with Terraform

1. Initialize Terraform:

```sh
terraform init
```

2. Review the Terraform plan to see the resources that will be created on AWS:

```sh
terraform plan
```

3. Apply the Terraform plan to deploy the resources:

```sh
terraform apply
```

When prompted, review the resources to be created and enter `yes` to confirm the deployment.

1. After applying the Terraform configuration, Terraform will output the command needed to query the API using curl. This command will be in the format:

```sh
Outputs:

curl_command = "curl http://<load_balancer_dns>"
load_balancer_dns = "<load_balancer_dns>"
```

Replace `<your_load_balancer_dns>` with the actual load balancer DNS name outputted by Terraform.
The successful response should be a JSON payload containing the current epoch time:

```json
{"The current epoch time": <epoch time value>}
```

5. To destroy the resources when they are no longer needed:

```sh
terraform destroy
```

## Resources Created

- VPC
- Subnets (x2)
- IGW
- Route Tables and Associations
- SG (ALB and Task)
- ALB
- ALB Target Group
- ALB Listener
- ECS Cluster
- ECS Task Definition
- ECS Service
