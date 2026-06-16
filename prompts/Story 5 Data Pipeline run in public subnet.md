# Data Pipeline use public subnet

We have a data pipeline that's presently in a private subnet.  The AWS Batch service there needs access to a few well 
known public AWS services: ECR (two endpoints), S3, SQS, and cloudwatch for logging.)

The cost of having AWS batch run in a private subnet adds $35/month due to the need for a private NAT gateway to allow 
connectivity to the aforementioned.  After more study, we've concluded that the need of 
a private subnet for our worker process is unecessary as security groups
are good enough to prevent any outside connections access AWS Batch.  AWS Batch needs to connect to the following
public services: ECR (which has two api endpoints: ECR API and ECR Docker registry), S3, SQS.  Using other strategies such as a private VPC link 
would cut the cost from a private NAT gateway
but only by around 50%.  

The fact that we are currently using two private subnets in two different availability zones for 
high availability, doubles the cost of using private VPC Links doubles the cost by requiring two private NAT gateways or
if going the VPC link route, that as well.  Since we are in startup mode, there isn't any need to do this as no revenue 
streams are interfered with in the unlikely event we have an outage in our AZ.  

All in all, it's not a good use of money as a private subnet is more valuable when you have
a collection of resources that are communicating bidirectionally with specific instances in the public.  We don't have 
that case as AWS Batch only needs to communicate with other AWS services that are running in the public AWS network.  
So we'd be adding cost for no material advantage.  Running AWS Batch in a public subnet allows us to use two AZs for no 
additional cost.

## Exploring the reasoning

```text
> So the principal I was following about putting workers in a private subnet is more nuanced.  If they're just 
> consumers, they don't need to be in a private subnet because the security is adequate if I have no inbound access 
> to the security group.

Exactly. You've just unlocked the key insight. The whole "private subnet = secure" thing is really about 
inbound attack surface, not about being hidden. If your security group has ***zero inbound rules***, it doesn't matter if 
you're technically in a public subnet — nothing can reach you anyway.
For batch workers that only pull container images and read data, a public subnet with locked-down ingress is perfectly 
fine and way cheaper. The "private subnet" principle was designed for when you actually need to restrict where 
traffic originates from, not as a blanket rule.

This reframes your decision: spend $35/month for architectural purity, or save that money and apply the security 
principle more intelligently. For a cost-conscious FinOps mindset, the latter wins.
```

```text
> What's the example of putting something in a public subnet that should be in a private subnet?

Good question. The classic case is a database or stateful backend service that should only be reachable from 
your application layer, not from the internet at large.
Say you have an RDS database in a public subnet with a security group that allows port 3306 inbound. 
Even if you think "nobody knows my database endpoint," you're exposed to:
    Brute force attacks on the database password
    Exploitation of database software vulnerabilities
    Accidental exposure if credentials leak

By putting it in a private subnet, you enforce that only resources inside your VPC (like your app servers) can even 
attempt to reach it — the public internet can't even try.
Another example: an internal API that your frontend shouldn't call directly, only your backend should. Private subnet 
forces that architecture; public subnet relies on security group rules, which can be misconfigured.

The pattern: if something should be reachable by a specific set of internal services but not the internet, 
private subnet. If something is one-directional outbound-only (like your batch workers), the security model is 
different and doesn't require it.
```

The vulnerability for using a public subnet at this point becomes the security group.  If the security group is
misconfigured to allow internet traffic to connect to AWS Batch, then the Batch service could be attacked.
We can look more deeply into this with threat modeling.  We should comment in the terraform plan that 
the security group configuration is protecting our pipeline and shouldn't allow connections from any address.

# Specification
Change the terraform plans (Infrastructure directory and terraform/datapipeline module) to implement the following:
- remove the NAT gateway for the private subnet
- remove the private subnet
- configure AWS Batch to run in two public subnets in two different AZs.

# Infrastructure/main.tf

provider "aws" {
  region = "us-west-2"
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "public_subnet_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-west-2a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-west-2b"
  map_public_ip_on_launch = true
}

# Note: Outputs or variables related to the removed NAT gateway and private subnet should also be removed if they exist.

# terraform/datapipeline/networking.tf

resource "aws_security_group" "batch_sg" {
  vpc_id = aws_vpc.main.id

  # Removed ingress rules to ensure no inbound access
  # Egress rules will allow outbound HTTPS and required AWS service access
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  # Additional egress rules may be added for other required services
  egress {
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 123
    to_port     = 123
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  subnets             = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]
}

resource "aws_batch_compute_environment" "batch_compute_env" {
  compute_resources {
    type                 = "EC2"
    min_vcpus           = 0
    max_vcpus           = 10
    desired_vcpus       = 5
    instance_role       = aws_iam_role.batch_instance_role.arn
    instance_type       = ["optimal"]
    subnets             = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]
    security_group_ids  = [aws_security_group.batch_sg.id]
  }

  service_role = aws_iam_role.batch_service_role.arn
  type        = "MANAGED"
}

# Note: Outputs or variables related to the removed NAT gateway and private subnet should also be removed if they exist.

# Module Validation for Subnets
# The datapipeline module should accept two existing public subnet IDs.
# Update validation/documentation for internet connectivity through IGW only, no NAT Gateway required.
