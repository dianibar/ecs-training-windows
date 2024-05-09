



<div align="center">

  <h1 align="center">ECS Training</h3>

</div>

## Launching an EC2 Windows instance

1. Go to https://ap-southeast-2.console.aws.amazon.com/ec2.
2. Select **Launch onstaces**.
3. Name windows-bastion.
4. In Quick Start select Windows
5. Amazon Machine Image (AMI) Microsoft Windows Server 2022 Base
Be sure to select a key pair
7. Select **Launch instance** 
8. Select the new created instance and go to the button **Connect**
9. Select the tab **RDP client**
10. Select **Connect using RDP Client**
11. Click in the **Get password** text and Upload private key file
12. Click the bottom **Decrypt password** and copy the password to provide in the RDP client
13. Connect to the instance using an RDP client, the public IP, and password.
14. Create the EC2 instance profile role to be able to login with the ECR repository and create resources via Terraform
* Open the IAM console.
* Choose Roles.
* Choose Create role
* Choose AWS Service and then choose EC2 from the list.
* Choose Next: Permissions and search and check the IAM policy AdministratorAccess
15. Add the role to the instance:
* Go to https://console.aws.amazon.com/ec2 and select the instance.
* In the drop down list **Actions** select **Security** and the Modify IAM role
* Choose the role that was created in the previous step and select **Update IAM role**

## Installing docker (Moby) on Windows

1. Open PowerShell as administrator and run the following command
```
Invoke-WebRequest -UseBasicParsing "https://raw.githubusercontent.com/microsoft/Windows-Containers/Main/helpful_tools/Install-DockerCE/install-docker-ce.ps1" -o install-docker-ce.ps1

.\install-docker-ce.ps1
```

## Getting to know Docker

1. Let's start by running docker --version to confirm that both the client and server are there and working.

```
docker --version
```

2. Docker containers are built using images. Let's run the following command to pull down the Nano Server trusted image from Docker Hub.

```
docker pull mcr.microsoft.com/windows/nanoserver:ltsc2022
```

3. Now run docker images to verify that the image is now on your local machine's Docker cache:

```
docker images
```

4. Now run a container using the image

```
docker run -it --user ContainerAdministrator mcr.microsoft.com/windows/nanoserver:ltsc2022 cmd.exe
```

5. Open another PowerShell terminal and run the following command

```
docker ps
```

7. In the initial PowerShell terminal. After the container is started, the command prompt window changes context to the container. Inside the container, we'll create a simple ‘Hello World’ text file and then exit the container by entering the following commands:

```
echo "Hello World!" > Hello.txt
exit
```

8. Get the container ID for the container you just exited by running the docker ps command:

```
docker ps -a
```

9. Create a new ‘HelloWorld’ image that includes the changes in the first container you ran. To do so, run the docker commit command, replacing <containerid> with the ID of your container:

```
docker commit <containerid> helloworld
```

10. Check the image that was created

```
docker images
```

11. Run the new image and check that the helloworld file is there

```
docker run -it helloworld cmd.exe
```

## Push and Pull and Image to ECR

### Create the repository
1. Open the Amazon ECR console at https://console.aws.amazon.com/ecr/.
2. Choose Get Started.
3. For Visibility settings, choose Private.
4. For Repository name, specify a name for the repository aspnetapp.
5. For Tag immutability, choose the tag mutability setting for the repository.

### push an image to ECR
1. Install AWS CLI and check the installation:

```
msiexec.exe /i https://awscli.amazonaws.com/AWSCLIV2.msi

aws --version
```

2. authenticate with the repository

```
 aws ecr get-login-password --region ap-southeast-2 | docker login --username AWS --password-stdin <account_number>.dkr.ecr.<region>.amazonaws.com
```
2. run the following command. It will download the image with a sample application locally

```
docker run --name aspnet_sample --rm -it -p 8000:80 mcr.microsoft.com/dotnet/framework/samples:aspnetapp
```
Note: if you get the error **hcsshim::ImportLayer failed in Win32: The system cannot find the path specified** Run
the following commands and try to run it again

```
docker images prune

docker system prune
```
3. Open a new PowerShell window and check the image

```
docker images
```
4. Tag the image with the repository URI:
```
docker tag <image id> <account_number>.dkr.ecr.<region>.amazonaws.com/aspnetapp:latest

```
5. Push the image to ECR


## Create networking, cluster and ECS service

1. Install terraform

* Download terraform:
```
Invoke-WebRequest https://releases.hashicorp.com/terraform/1.8.3/terraform_1.8.3_windows_386.zip -OutFile C:\terraform_1.8.3_windows_386.zip
```
* Unzip the content
```
Expand-Archive -LiteralPath 'C:\terraform_1.8.3_windows_386.zip' -DestinationPath C:\terraform
```
* Modify the system environment variable:
```
  $env:Path = 'C:\terraform;' + $env:Path 
 setx PATH "$env:path;C:\terraform" -m
```

2. Clone the training repository.

```
git clone https://github.com/dianibar/ecs-training-windows.git
```
2. Open the file ecs-training/ecs-cluster/complete/main.tf and replace <user> 
the string with your own name

```
name   = "<user>-${basename(path.cwd)}"
container_cw_log_group = "/aws/ecs/<user>/ecsdemo-frontend"
```
2. Apply the terraform template.
```
cd ecs-training/ecs-cluster
terraform init
terraform apply
```
3. Explore the cluster and the resources created.

## Access the container using ECS Exec

Open the file ecs-training/ecs-cluster/complete/main.tf and do the following 
modifications:

1. Modify the cluster to configure the CloudWatch log group where the exec 
   will be logged
```
   ...
   cluster_name = local.name

   cluster_configuration = {
    execute_command_configuration = {
      logging = "OVERRIDE"
      log_configuration = {
        cloud_watch_log_group_name = "/aws/ecs/ecs-exec-demo"
      }
    }
  } 
  
  services = {

  ```
2. In the container enable ecs-exec using 'enable_execute_command = true'

```
    ecsdemo-frontend = {
      enable_execute_command = true
      cpu    = 1024
```

3. Add permissions to the service task to access ssm and CloudWatch Logs:

```
      tasks_iam_role_statements = [
        {
          actions   = ["s3:List*"]
          resources = ["arn:aws:s3:::*"]
        },
        {
          actions   = ["logs:CreateLogStream", 
            "logs:PutLogEvents", 
            "logs:DescribeLogStreams"]
          resources = ["*"]
        },
        {
          actions   = ["ssmmessages:CreateControlChannel",
            "ssmmessages:CreateDataChannel",
            "ssmmessages:OpenControlChannel",
            "ssmmessages:OpenDataChannel"]
          resources = ["*"]
        }

      ]
```
4. Apply the changes

```
terraform apply
```
5. Access the container

```
 aws ecs execute-command \
  --region ap-southeast-2 \
  --cluster <clustername> \
  --task <taskid> \
  --container <containername> \
  --command "/bin/bash" \
  --interactive
```

## Add Fargate Spot instances

1. Add the capacity provider to the cluster

```
...
 cluster_configuration = {
    execute_command_configuration = {
      logging = "OVERRIDE"
      log_configuration = {
        cloud_watch_log_group_name = "/aws/ecs/ecs-exec-demo"
      }
    }
  }

  # Capacity provider
  fargate_capacity_providers = {
    FARGATE = {
      default_capacity_provider_strategy = {
        weight = 1
        base   = 1
      }
    }
    FARGATE_SPOT = {
      default_capacity_provider_strategy = {
        weight = 1
      }
    }
  }

  services = {
...
```
2. Open the file ecs-training/ecs-cluster/complete/main.tf and add the capacity provider to the service:

```
  services = {
    ecsdemo-frontend = {
      capacity_provider_strategy = {
        fargate = {
          capacity_provider = "FARGATE"
          weight            = 1
          base              = 1
        }
        spot = {
          capacity_provider = "FARGATE_SPOT"
          weight            = 1
        }
      }
```
2. Apply the changes

``` 
terraform apply
```

3. Modify the desired_count to four
```
    ecsdemo-frontend = {
    
      capacityProviderStrategy = {
          "capacityProvider": "FARGATE_SPOT",
          "weight": 1,
          "base": 0
      }
      capacityProviderStrategy = {
          "capacityProvider": "FARGATE",
          "weight": 1,
          "base": 1
      }
      
      enable_execute_command = true
      
      desired_count          = 4
      cpu                    = 1024
```
5. Apply the changes
``` 
terraform apply
```
## Create a scheduled task in the EventBridge Scheduler console

1. Open the Amazon EventBridge Scheduler console at https://console.aws.amazon.com/scheduler/home.

2. On the Schedules page, choose Create schedule.

3. On the Specify schedule detail page, in the Schedule name and description section.
For Schedule group choose default.

4. Choose your schedule options. https://docs.aws.amazon.com/scheduler/latest/UserGuide/schedule-types.html#cron-based

5. Choose Next.

6. On the Select target page, do the following:

    * Choose All APIs, and then in the search box enter ECS.

    * Select Amazon ECS.

    * In the search box, enter RunTask, and then choose RunTask.

    * For ECS cluster, choose the cluster.

   * For ECS task, choose the task definition to use for the task.

   * To use a launch type, expand Compute options, and then select Launch type. Then, choose the launch type FARGATE.

   * Leave Platform version empty. If there is no platform specified, the LATEST platform version is used.

   * For Subnets, choose one of the public subnets 

   * For Security groups, enter the security group IDs for the VPC the one with the port  80 open to everywhere.

   * Enable Auto-assign public IP

   * Leave the default for the other options

<!-- ACKNOWLEDGMENTS -->
## Acknowledgments

* [Getting started with Cloud 9](https://aws-quickstart.github.io/workshop-terraform-modules/40_setup_cloud9_ide/40_start_cloud9.html)
* [Running a Batch job using AWS Batch and Docker Image](https://sivachandanc.medium.com)
* [Using Amazon ECS Exec for debugging](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-exec.html)


<p align="right">(<a href="#readme-top">back to top</a>)</p>