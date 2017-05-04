#!/bin/bash

ACCOUNT_PATH="${1}"
CERTS_PATH="${2}"
config="config.json"
lets_encrypt_api="${3:-staging}"

source ./functions.sh

if [[ $# -lt 2 ]]; then
    usage
fi

noOfAWSAccounts=$(cat $config | jq -r '.' | jq length)
for ((i=0; i<${noOfAWSAccounts}; i++));
do
  ## Reset Values
  domain_list_options=""
  ## Extract individual Account Details ##
  account_details=$(cat $config | jq -r .[$i] | jq -r '[.account, .domains, .aws_certificate_name, .destination_type, .force_renew, .s3]')
  account=$(echo $account_details | jq -r . | jq -r .[0])
  domains=$(echo $account_details | jq -r . | jq -r .[1])
  noOfDomains=$(echo $account_details | jq -r . | jq -r .[1] | jq length)
  aws_certificate_name=$(echo $account_details | jq -r . | jq -r .[2])
  destination_type=$(echo $account_details | jq -r . | jq -r .[3])
  force_renew=$(echo $account_details | jq -r . | jq -r .[4])
  s3=$(echo $account_details | jq -r . | jq -r .[5])

  echo "Extract individual Account Details: "
  echo "Account: ${account}"
  echo "Domains: ${domains}"
  echo "No of Domains: ${noOfDomains}"
  echo "AWS Certificate Name: ${aws_certificate_name}"

  ## Assume Account Role ##  
  ## Code to Assume role ##

  ## Verify Certificate Expiration
  if [[ $force_renew == "true" ]]; then
    create_certs="true"
  else
    create_certs=$(verifyAWSCertificateExistsOrExpired $aws_certificate_name)
  fi       
  echo "Verify if Certificate ${aws_certificate_name} needs Creation or Expired: ${create_certs}"

  
  if [[ $create_certs == "true" ]]; then
  ## Create SAN Certificate
    for ((j=0; j<${noOfDomains}; j++));
    do
      next_domain=""
      next_domain=$(echo $domains | jq -r .[$j])
      echo "Adding domain name: ${next_domain}"
      if [[ ! -z $next_domain ]]; then
        domain_list_options="${domain_list_options} -d ${next_domain} "
      fi      
    done

    echo "Creating Certificate for : ${domain_list_options}"
    cert_creation_result=$(createLetsEncryptCertificate "${ACCOUNT_PATH}" "${CERTS_PATH}" "${domain_list_options}" "${lets_encrypt_api}")
    echo "Result of Certificate Creation: Success"

    if [[ $destination_type == "aws_iam" ]]; then
      echo "Uploading certs to AWS IAM"
      first_domain=$(echo $domains | jq -r .[0])
      echo "${first_domain}"
      echo "${aws_certificate_name}"
      echo "${CERTS_PATH}/${first_domain}/ca.cer"
      echo "${CERTS_PATH}/${first_domain}/${first_domain}.key"
      echo "${CERTS_PATH}/${first_domain}/${first_domain}.cer"

      importCertToAWSIAM "${aws_certificate_name}" "file://${CERTS_PATH}/${first_domain}/ca.cer" "file://${CERTS_PATH}/${first_domain}/${first_domain}.key" "file://${CERTS_PATH}/${first_domain}/${first_domain}.cer"

    fi

    ## upload encrypted certs to s3 bucket, make sure bucket does exist and accessible!!
    if [[ ! -z $s3 ]]; then
        echo "Start uploading to S3";
        echo "${CERTS_PATH}/${first_domain}/ca.cer"
        echo "${CERTS_PATH}/${first_domain}/${first_domain}.key"
        echo "${CERTS_PATH}/${first_domain}/${first_domain}.cer"
        kms -e "${CERTS_PATH}/${first_domain}/ca.cer" > "${CERTS_PATH}/${first_domain}/ca.cer.kms"
        kms -e "${CERTS_PATH}/${first_domain}/${first_domain}.key" > "${CERTS_PATH}/${first_domain}/${first_domain}.key.kms"
        kms -e "${CERTS_PATH}/${first_domain}/${first_domain}.cer" > "${CERTS_PATH}/${first_domain}/${first_domain}.cer.kms"
        aws s3api put-object --bucket "${s3}" --key "ca.cer.kms" --body "${CERTS_PATH}/${first_domain}/ca.cer.kms"
        aws s3api put-object --bucket "${s3}" --key "${first_domain}.key.kms" --body "${CERTS_PATH}/${first_domain}/${first_domain}.key.kms"
        aws s3api put-object --bucket "${s3}" --key "${first_domain}.cer.kms" --body "${CERTS_PATH}/${first_domain}/${first_domain}.cer.kms"
        echo "uploading to s3 done"
    fi
  fi  
done

echo "acme.sh Account Path: ${ACCOUNT_PATH}"
echo "acme.sh Generated Path: ${CERTS_PATH}"
echo "generated for ${noOfAWSAccounts} Accounts"
