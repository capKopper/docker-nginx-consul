FROM nginx:1.9.4

RUN apt-get update && \
    apt-get install wget curl unzip -y

# Install consul-template
# (https://github.com/hashicorp/consul-template)
ENV CT_VER 0.10.0
RUN wget -q -O /tmp/ct.zip https://releases.hashicorp.com/consul-template/${CT_VER}/consul-template_${CT_VER}_linux_amd64.zip && \
    unzip /tmp/ct.zip -d /usr/local/bin/ && \
    chmod +x /usr/local/bin/consul-template && \
    rm -f /tmp/ct.zip

ADD templates/ /consul-template/templates
ADD config/ /consul-template/config/
ADD scripts/ /scripts/
RUN chmod +x /scripts/*

RUN echo ""  > /usr/share/nginx/html/index.html

CMD ["/scripts/init.sh"]