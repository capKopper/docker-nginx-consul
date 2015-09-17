FROM nginx:1.9.4

ENV CT_VERSION 0.10.0

RUN apt-get update && \
    apt-get install wget -y
RUN cd /tmp && \
    wget https://github.com/hashicorp/consul-template/releases/download/v${CT_VERSION}/consul-template_${CT_VERSION}_linux_amd64.tar.gz && \
    tar xzf consul-template_${CT_VERSION}_linux_amd64.tar.gz && \
    mv consul-template_${CT_VERSION}_linux_amd64/consul-template /usr/local/bin && \
    chmod +x /usr/local/bin/consul-template && \
    rm -fr consul-template_${CT_VERSION}_linux_amd64*

ADD templates/ /consul-template/templates
ADD config/ /consul-template/config/
ADD scripts/ /scripts/
RUN chmod +x /scripts/*

RUN echo ""  > /usr/share/nginx/html/index.html

CMD ["/scripts/init.sh"]