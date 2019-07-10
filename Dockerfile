FROM tomcat:9-jre8


# persistent / runtime deps
RUN apt-get update && \
    apt-get -y upgrade && \
    apt-get install -y --no-install-recommends apt-utils libnetcdf-c++4 curl unzip && \
    rm -r /var/lib/apt/lists/*

ENV NOTO_FONTS="NotoSans-unhinted NotoSerif-unhinted NotoMono-hinted" \
    GOOGLE_FONTS="Open%20Sans Roboto Lato Ubuntu" \
    GEOSERVER_VERSION="2.15.2" \
    GEOSERVER_PLUGINS="css grib imagemosaic-jdbc mongodb netcdf pyramid vectortiles wps ysld" \
    GEOSERVER_HOME="/usr/local/tomcat/webapps/geoserver" \
    GEOSERVER_DATA_DIR="/usr/local/geoserver" \
    CATALINA_TMPDIR="/usr/local/temp" \
    JAVA_OPTS="-Djava.awt.headless=true -Xbootclasspath/a:${JAVA_HOME}/jre/lib/ext/marlin-0.9.2-Unsafe.jar -Xbootclasspath/p:${JAVA_HOME}/jre/lib/ext/marlin-0.9.2-Unsafe-sun-java2d.jar -Dsun.java2d.renderer=org.marlin.pisces.MarlinRenderingEngine -XX:+UseG1GC"

# Make temp directory
RUN mkdir /usr/local/temp

# Install Google Noto fonts
RUN mkdir -p /usr/share/fonts/truetype/noto && \
    for FONT in ${NOTO_FONTS}; \
    do \
        curl -sS -O https://noto-website-2.storage.googleapis.com/pkgs/${FONT}.zip && \
    	unzip -o ${FONT}.zip -d /usr/share/fonts/truetype/noto && \
    	rm -f ${FONT}.zip ; \
    done

# Install Google Fonts
RUN \
    for FONT in $GOOGLE_FONTS; \
    do \
        mkdir -p /usr/share/fonts/truetype/${FONT} && \
        curl -sS -o ${FONT}.zip "https://fonts.google.com/download?family=${FONT}" && \
    	unzip -o ${FONT}.zip -d /usr/share/fonts/truetype/${FONT} && \
    	rm -f ${FONT}.zip ; \
    done

# Install native JAI
RUN \
    cd $JAVA_HOME && \
    curl -sS -L -O https://download.java.net/media/jai/builds/release/1_1_3/jai-1_1_3-lib-linux-amd64-jre.bin && \
    echo "yes" | sh jai-1_1_3-lib-linux-amd64-jre.bin && \
    rm jai-1_1_3-lib-linux-amd64-jre.bin

# Install ImageIO
RUN \
    cd $JAVA_HOME && \
    export _POSIX2_VERSION=199209 &&\
    curl -sS -L -O https://download.java.net/media/jai-imageio/builds/release/1.1/jai_imageio-1_1-lib-linux-amd64-jre.bin && \
    echo "yes" | sh jai_imageio-1_1-lib-linux-amd64-jre.bin && \
    rm jai_imageio-1_1-lib-linux-amd64-jre.bin

# Get Marlin Renderer
RUN \
    cd $JAVA_HOME/lib/ext/ && \
    curl -L -sS -O https://github.com/bourgesl/marlin-renderer/releases/download/v0_9_2/marlin-0.9.2-Unsafe.jar && \
    curl -L -sS -O https://github.com/bourgesl/marlin-renderer/releases/download/v0_9_2/marlin-0.9.2-Unsafe-sun-java2d.jar && \
    curl -L -sS -O https://jdbc.postgresql.org/download/postgresql-42.0.0.jar

#
# GEOSERVER INSTALLATION
#

# Install GeoServer
RUN curl -sS -L -O http://sourceforge.net/projects/geoserver/files/GeoServer/$GEOSERVER_VERSION/geoserver-$GEOSERVER_VERSION-bin.zip && \
    unzip geoserver-$GEOSERVER_VERSION-bin.zip && mv -v geoserver-$GEOSERVER_VERSION/webapps/geoserver $GEOSERVER_HOME && \
    rm geoserver-$GEOSERVER_VERSION-bin.zip && \
    sed -e 's/>PARTIAL-BUFFER2</>SPEED</g' -i $GEOSERVER_HOME/WEB-INF/web.xml && \
    # Remove old JAI from geoserver
    rm -rf $GEOSERVER_HOME/WEB-INF/lib/jai_codec-*.jar && \
    rm -rf $GEOSERVER_HOME/WEB-INF/lib/jai_core-*jar && \
    rm -rf $GEOSERVER_HOME/WEB-INF/lib/jai_imageio-*.jar && \
    rm -rf $GEOSERVER_HOME/WEB-INF/lib/marlin-*.jar

# Make Geoserver data dir
VOLUME $GEOSERVER_DATA_DIR

# Satellittbilder
VOLUME /usr/local/satellittbilder

# Install GeoServer Plugins
RUN for PLUGIN in ${GEOSERVER_PLUGINS}; \
    do \
      curl -sS -L -O http://sourceforge.net/projects/geoserver/files/GeoServer/$GEOSERVER_VERSION/extensions/geoserver-$GEOSERVER_VERSION-$PLUGIN-plugin.zip && \
      unzip -o geoserver-$GEOSERVER_VERSION-$PLUGIN-plugin.zip -d $GEOSERVER_HOME/WEB-INF/lib/ && \
      rm geoserver-$GEOSERVER_VERSION-$PLUGIN-plugin.zip ; \
    done

# Expose GeoServer's default port
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=10s\
    CMD curl -f "http://localhost:8080/geoserver/ows?service=wms&version=1.3.0&request=GetCapabilities" || exit 1

COPY docker-entrypoint.sh /

RUN chgrp -R 0 $GEOSERVER_HOME && \
    chmod -R g=u $GEOSERVER_HOME /etc/passwd /var/log /usr/local/temp


ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["geoserver"]
 