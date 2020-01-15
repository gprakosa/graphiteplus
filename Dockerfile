FROM gprakosa/nagiosplus-baseimage
LABEL maintainer "gprakosa <godhot.prakosa@gmail.com>"
LABEL original-maintainer "ethnchao <maicheng.linyi@gmail.com>"

ENV GRAPHITE_VERSION        1.1.6
ENV GRAFANA_VERSION         6.5.2

# Remove if you encounter error "hash sum mismatch"
ADD config/apt-sources-kambing.list /etc/apt/sources.list

# Install Apache Mod WSGI Python3
RUN apt-get update && apt-get install -y libapache2-mod-wsgi-py3

# Install Graphite
RUN virtualenv --python=python3.5 /opt/graphite && \
  . /opt/graphite/bin/activate && \
  pip install --no-cache-dir cffi scandir && \
  pip install --no-cache-dir --no-binary=:all: \
    https://github.com/graphite-project/whisper/archive/${GRAPHITE_VERSION}.zip \
    https://github.com/graphite-project/carbon/archive/${GRAPHITE_VERSION}.zip \
    https://github.com/graphite-project/graphite-web/archive/${GRAPHITE_VERSION}.zip && \
  deactivate

ADD config/carbon.conf /opt/graphite/conf/carbon.conf
RUN cd /opt/graphite/conf/ && \
  cp storage-schemas.conf.example storage-schemas.conf && \
  cp graphite.wsgi.example graphite.wsgi && \
  cp storage-aggregation.conf.example storage-aggregation.conf && \
  sed -i 's/import sys/import sys, site/' graphite.wsgi && \
  sed -i '/import sys, site/a\site.addsitedir("/opt/graphite/lib/python3.5/site-packages")' graphite.wsgi && \
  cd /opt/graphite/webapp/graphite/ && \
  cp local_settings.py.example local_settings.py && \
  . /opt/graphite/bin/activate && \
  export PYTHONPATH="/opt/graphite/lib/:/opt/graphite/webapp/" && \
  django-admin.py migrate --settings=graphite.settings --run-syncdb && \
  unset PYTHONPATH && \
  deactivate && \
  chown -R www-data:www-data /opt/graphite/storage && \
  cd /etc/apache2/sites-available/ && \
  cp /opt/graphite/examples/example-graphite-vhost.conf graphite.conf && \
  sed -i 's/80/8080/' graphite.conf && \
  sed -i 's;WSGISocketPrefix run/wsgi;WSGISocketPrefix /var/run/apache2/wsgi;' graphite.conf && \
  a2ensite graphite && \
  echo "Listen 8080" >> /etc/apache2/ports.conf

# It's might takes long times to download Grafana. You need to provide the binary yourself.
# You can check https://github.com/grafana/grafana/releases for the latest.

# Install Grafana
COPY grafana_${GRAFANA_VERSION}_amd64.deb /
RUN apt install /grafana_${GRAFANA_VERSION}_amd64.deb &&\
rm /grafana*

ADD run.sh /run.sh
ADD config/sv/apache/run /etc/sv/apache/run
ADD config/sv/carbon/run /etc/sv/carbon/run

RUN rm -rf /etc/sv/getty-5 && \
  chmod +x /run.sh /etc/sv/apache/run /etc/sv/carbon/run && \
  ln -s /etc/sv/* /etc/service

ENV APACHE_LOCK_DIR /var/run
ENV APACHE_LOG_DIR /var/log/apache2

EXPOSE 2004
EXPOSE 3000

ENTRYPOINT [ "/run.sh" ]

CMD { "main" ]
