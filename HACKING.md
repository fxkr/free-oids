# Design

## Requirements

The software was designed with the following in mind:

* Must guarantee consistency. (This is the entire point of the OID system.)

* Must be based on AWS and Terraform (I want to play with these.)

* Must require zero maintenance once running (I am running enough infrastructure already.)

* Must be free to run indefinitely (And I am paying enough for said infrastructure too.)

So this is not exactly an example of how one would use AWS for enterprise software ;-)


## Cost

$0.50/month for Route53 for a hosted zone. I don't see a way to get around this. :-(

Everything else is pay per request, and I am way below the free tier limits.


## Prerequisites

Before deploying you need:

* An AWS account, obviously.

* The zone id of a Route 53 zone. Deployment of the zone is out of scope.

* Google reCAPTCHA credentials (public and secret key).

* An OID prefix that you want to assign sub-prefixes in.


## Deployment

Create a hosted zone in Route 53 manually and make DNS work.

Fill out `terraform.tfvars` (see `terraform.tfvars.example`).

`terraform apply` until it works. (It'll probably fail initially because of certificate validation delay.)
