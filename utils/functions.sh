#!/bin/bash

function usage () {
  echo "Usage: ssl_generator.sh [account_path] [certs_path]"
}

function verifyAWSCertificateExistsOrExpired () {
  local aws_certificate_name=$1

  expiration_date_aws=$(aws iam list-server-certificates | jq -r --arg "certificate_name" "${aws_certificate_name}" '.ServerCertificateMetadataList | map(select(.ServerCertificateName  == $certificate_name)) | .[] | .Expiration')
  create_certs=true
  if [[ ! -z $expiration_date_aws ]]; then   
    expiration_date=$([ "$(uname)" = Linux ] && date --date="${expiration_date_aws}" +%s || date -j -f '%Y-%m-%dT%H:%M:%SZ' "${expiration_date_aws}" '+%s')
    current_date=$(date +%s)
    cert_expire_diff=$(expr $expiration_date - $current_date)
    if (($cert_expire_diff > 604800)); then
      create_certs=false
    fi
  fi

  echo $create_certs
}

function createLetsEncryptCertificate () {
  local account_path=$1
  local certificate_path=$2
  local domain_list_options=$3
  local lets_encrypt_api=$4
  local le_api_option=""

  if [[ $lets_encrypt_api == "staging" ]]; then
      le_api_option="--staging"
  fi

  docker run --name letsencrypt \
      -v ${certificate_path}:/certs \
      -v ${account_path}:/account \
      -e AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} \
      -e AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} \
       -e AWS_SESSION_TOKEN=${AWS_SESSION_TOKEN} \
       --rm gssumesh/letsencrypt_ssl_generator:v1 \
       ${le_api_option} \
       --issue --insecure --debug--dns dns_aws \
       ${domain_list_options}

}

function importCertToAWSIAM () {
  local aws_certificate_name=$1
  local ca_path=$2
  local cert_key=$3
  local cert_file=$4

  aws_upload_result=$(aws iam upload-server-certificate --server-certificate-name $aws_certificate_name --certificate-body $cert_file --private-key $cert_key --certificate-chain $ca_path)
  echo $aws_upload_result
}