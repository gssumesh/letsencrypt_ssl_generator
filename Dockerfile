FROM alpine:3.4

RUN apk add --no-cache busybox curl tar git openssl netcat-openbsd

# Internal
ENV ACME_DIR /acme.sh
ENV LE_WORKING_DIR $ACME_DIR
ENV TEMP_DIR /tmp/acme.sh

# External
ENV CERT_DIR /certs
ENV ACCOUNT_DIR /account
ENV AWS_ACCESS_KEY_ID enter_access_key
ENV AWS_SECRET_ACCESS_KEY enter_secret_key
ENV AWS_SESSION_TOKEN enter_session_token
ENV DOMAIN_NAME enter.your.domain.name

RUN git clone --depth 1 https://github.com/Neilpang/acme.sh.git ${TEMP_DIR} \
    &&  mkdir -p ${CERT_DIR} ${ACCOUNT_DIR} \
    && cd /tmp/acme.sh \
    && ./acme.sh --install \
       --home ${ACME_DIR} \
       --certhome ${CERT_DIR} \
       --accountkey ${ACCOUNT_DIR}/account.key \
       --useragent "acme.sh in docker" \
    && ln -s ${ACME_DIR}/acme.sh /usr/local/bin \
    && rm -rf ${TEMP_DIR}

RUN crontab -r

VOLUME $CERT_DIR
VOLUME $ACCOUNT_DIR

ENTRYPOINT ["acme.sh"]
CMD ["--help"]

ARG build_no
ARG git_revision

LABEL build_number="$build_no"
LABEL git_revision="$git_revision"