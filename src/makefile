# VERSION numbers
POSTGRES_VERSION=9.4.1.0
WILDFLY_VERSION=8.2.0
ICE_VERSION=4.1.12
BLAST_VERSION=2.2.30+

# commands used for downloading and extracting sources
CURL=/usr/bin/curl -L10 --silent --show-error --remote-name

all: postgres wildfly ice blast

#########################
###### PostgresApp ######
#########################

postgres: /Applications/Postgres.app

/Applications/Postgres.app: Postgres-$(POSTGRES_VERSION).zip
	unzip -qq -o Postgres-$(POSTGRES_VERSION).zip
	mv Postgres.app /Applications/Postgres.app

Postgres-$(POSTGRES_VERSION).zip:
	$(CURL) "https://github.com/PostgresApp/PostgresApp/releases/download/$(POSTGRES_VERSION)/Postgres-$(POSTGRES_VERSION).zip"

#####################
###### WildFly ######
#####################

wildfly: wildfly-$(WILDFLY_VERSION).Final

wildfly-$(WILDFLY_VERSION).Final: wildfly-$(WILDFLY_VERSION).Final.zip
	unzip -qq -o wildfly-$(WILDFLY_VERSION).Final.zip
	cp standalone_bg.sh wildfly-$(WILDFLY_VERSION).Final/bin
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
