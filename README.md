# LetsEncrypt based SSL generation docker image (uses acme.sh as client library)

## Description
This docker image is built with acme.sh library which is a pure shell script based letsencrypt client i
mplementation. Image lets you attach two volumes one for Account keys and Certificates. Entrypoint for the image is acme.sh client and hence accepts all parameter supported by acme.sh. Since majority AWS hosted apps use AWS Route 53 for domain name, best way to get SSL certs is with dns validation and verification through AWS API. It is recommended to retrieve AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY and AWS_SESSION_TOKEN before executing the container. Let me know if you need to add support for more services.


Repository is organised into following directories and files :
 1. Root / Dockerfile : helps to create LetsEncrypt docker image based on acme.sh client
 2. utils : Script to leverage docker image and automatically create certs and upload to IAM or s3 bucket based on config file. It also has provision to upload cert to AWS IAM and option to force renew.


## Important Link
[acme.sh](https://github.com/Neilpang/acme.sh)

[acme.sh DNS](https://github.com/Neilpang/acme.sh/tree/master/dnsapi)

[letsencrypt](https://letsencrypt.org/)

## Usage

### Prerequisites
1. Docker
2. Install jq commandline utility : to use utility
3. aws cli : to use utility

### Standalone Usage
[To generate the certs manually with docker container]

```sh
docker run --name letsencrypt \
     -v /HOST/CERT/PATH:/certs \
     -v /HOST/ACCOUNT/PATH:/account \
     -e AWS_ACCESS_KEY_ID=[AWS_ACCESS_KEY_ID] \
     -e AWS_SECRET_ACCESS_KEY=[AWS_SECRET_ACCESS_KEY] \
     -e AWS_SESSION_TOKEN=[AWS_SESSION_TOKEN] \
     --rm gssumesh/letsencrypt_ssl_generator:v1 \
     --issue --dns dns_aws -d your.domain.name.com
```

### Cerficate Generation through config file
 [Use to generate certificate through config file. Used for automatic generation. You can extend it to assume role across account]

 This sample utility script will read config file, verify if certificate exist in AWS IAM. If it exist and is about to expire OR if it doesn't exist, then we will create a new certificate with our docker image. We will then upload the same to AWS IAM and optionally push it to s3 bucket.

(Recommended) LetsEncrypt have API limit [LetsEncrypt Rate Limit](https://letsencrypt.org/docs/rate-limits/) hence encourage everyone to use LetsEncrypt staging API for testing.
(Recommended) Combine all domains together to create SAN certificate.

To hit staging LetsEncrypt follow this instruction:

```sh
cd utils
./ssl_generator.sh "/Absolute/Path/to/some/folder/as/account" "/Absolute/Path/to/some/folder/as/cert"
```

To use script and generate real certificate with LetsEncrypt, follow this instruction:

```sh
cd utils

./ssl_generator.sh "/Absolute/Path/to/some/folder/as/account" "/Absolute/Path/to/some/folder/as/cert" "production"
```

## How it works : ./ssl_generator.sh

This script accepts three parameters :

  1. account_path : Can be an empty directory or any directory. This path is mounted to letsencrypt docker image as account path, which is needed by acme.sh library which we use.
  2. certs_path : Can be an empty directory or any directory. This path is mounted to letsencrypt docker image as certs path, which is needed by acme.sh library to generate certificate.
  3. letsencrypt_api : (OPTIONAL), It defaults to staging api. If value is any other value then it hits "Production" LetsEncrypt API for real certificates.


Anatomy:
  1. Refers config.json to start generating certificates.
  2. Loop through each item in config.
  3. If "force_renewal" set in config as true, then it starts generating certificate.
  4. If "force_renewal" set in config as false, then it verifies if certificate with name "aws_certificate_name" in config exist in AWS IAM and is not expired. It decides if it needs to generate certificate.
  5. Creation of certificate : Combines all the domain and use custom LetsEncrypt docker container to generate SAN certificate and place in mounted "certs_path" folder
  6. If "destination_type" is aws_iam, then upload generated certificate to AWS IAM of assumed account

