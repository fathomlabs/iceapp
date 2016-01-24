# VERSION numbers
POSTGRES_VERSION=9.4.1.0
POSTGRES_MAJOR_VERSION=9.4
WILDFLY_VERSION=8.2.0
ICE_VERSION=4.1.12
BLAST_VERSION=2.2.30+
PG_DIR=/Applications/Ice.app/Contents/Versions/postgres-$(POSTGRES_MAJOR_VERSION)

# There is no JRE version defined here because we always download the
# most recent release of JRE 1.7 (see download_latest_JRE.ksh)
#
# This should be OK because JRE patch versions are never (supposed to be)
# breaking - and downloading them manually is a pain.

# commands used for downloading and extracting sources
CURL=/usr/bin/curl -L10 --silent --show-error --remote-name

all: javaruntime postgress wildfly ice blast

####################
######  Java  ######
####################

javaruntime:
	rm -rf jre-*
	./download_latest_JRE.ksh
	tar xf jre*gz
	rm jre*gz
	mv jre*.jre/Contents/Home jre
	rm -rf jre-*

#########################
###### PostgresApp ######
#########################

postgress:
	rm -rf /Applications/Ice.app
	mkdir -p $(PG_DIR)
	make -C ./postgres
	cd $(PG_DIR)/share; for file in $$(grep -ril "\$$libdir" .); \
	do \
	sed -e "s/\$$libdir/\/Applications\/Ice.app\/Contents\/Versions\/postgres-$(POSTGRES_MAJOR_VERSION)\/lib/g" $$file > /tmp/tempfile.tmp ;\
	mv /tmp/tempfile.tmp $$file ;\
	done

#####################
###### WildFly ######
#####################

wildfly: wildfly-$(WILDFLY_VERSION).Final

wildfly-$(WILDFLY_VERSION).Final: wildfly-$(WILDFLY_VERSION).Final.zip
	unzip -qq -o wildfly-$(WILDFLY_VERSION).Final.zip
	cp standalone_bg.sh wildfly-$(WILDFLY_VERSION).Final/bin
	cp iceserver.jks wildfly-$(WILDFLY_VERSION).Final/standalone/configuration/iceserver.jks
	rm wildfly-$(WILDFLY_VERSION).Final/standalone/configuration/standalone*.xml
	cp standalone-ice.xml wildfly-$(WILDFLY_VERSION).Final/standalone/configuration/standalone.xml

wildfly-$(WILDFLY_VERSION).Final.zip:
	$(CURL) "http://download.jboss.org/wildfly/8.2.0.Final/wildfly-$(WILDFLY_VERSION).Final.zip"

#################
###### ICE ######
#################

ice: ice-$(ICE_VERSION).war
	mkdir -p ice.war
	cp ice-$(ICE_VERSION).war ice.war/ice-$(ICE_VERSION).war
	cd ice.war; unzip -qq -o ice-$(ICE_VERSION).war
	pwd
	cp jboss-web.xml ice.war/WEB-INF/jboss-web.xml
	cp hibernate.cfg.xml ice.war/WEB-INF/classes/hibernate.cfg.xml
	cp -r ice.war wildfly-$(WILDFLY_VERSION).Final/standalone/deployments/
	rm -rf ice.war

ice-$(ICE_VERSION).war:
	$(CURL) "https://github.com/JBEI/ice/releases/download/$(ICE_VERSION)/ice-$(ICE_VERSION).war"

#################
##### BLAST #####
#################

blast: ncbi-blast-$(BLAST_VERSION)
	-mkdir -p blast_binaries
	cp ncbi-blast-$(BLAST_VERSION)/bin/{makeblastdb,blastn,tblastx} blast_binaries/

ncbi-blast-$(BLAST_VERSION): ncbi-blast-$(BLAST_VERSION)-universal-macosx.tar.gz
	tar xf ncbi-blast-$(BLAST_VERSION)-universal-macosx.tar.gz

ncbi-blast-$(BLAST_VERSION)-universal-macosx.tar.gz:
	$(CURL) "ftp://ftp.ncbi.nlm.nih.gov/blast/executables/blast+/LATEST/ncbi-blast-$(BLAST_VERSION)-universal-macosx.tar.gz"
