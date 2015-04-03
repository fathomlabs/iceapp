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
	# start postgres server temporarily
	-/Applications/Postgres.app/Contents/Versions/9.4/bin/pg_ctl -D ~/Library/Application\ Support/Postgres/var-9.4/ start
	sleep 3
	# create user
	-echo "CREATE ROLE iceserver WITH ENCRYPTED PASSWORD 'password';" | /Applications/Postgres.app/Contents/Versions/9.4/bin/psql
	# create database
	-/Applications/Postgres.app/Contents/Versions/9.4/bin/createdb --owner=iceserver icedb "ICE server database"
	# stop database
	- /Applications/Postgres.app/Contents/Versions/9.4/bin/pg_ctl -D ~/Library/Application\ Support/Postgres/var-9.4/ stop -m fast

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

wildfly-$(WILDFLY_VERSION).Final.zip:
	$(CURL) "http://download.jboss.org/wildfly/8.2.0.Final/wildfly-$(WILDFLY_VERSION).Final.zip"

#################
###### ICE ######
#################

ice: ice-$(ICE_VERSION).war
	cp ice-$(ICE_VERSION).war wildfly-$(WILDFLY_VERSION).Final/standalone/deployments/
	touch wildfly-$(WILDFLY_VERSION).Final/standalone/deployments/ice-$(ICE_VERSION).war.dodeploy

ice-$(ICE_VERSION).war:
	$(CURL) "https://github.com/JBEI/ice/releases/download/$(ICE_VERSION)/ice-$(ICE_VERSION).war"

#################
##### BLAST #####
#################

blast: ncbi-blast-$(BLAST_VERSION)
	-mkdir blast_binaries
	cp ncbi-blast-$(BLAST_VERSION)/bin/{makeblastdb,blastn,tblastx} blast_binaries/

ncbi-blast-$(BLAST_VERSION): ncbi-blast-$(BLAST_VERSION)-universal-macosx.tar.gz
	tar xf ncbi-blast-$(BLAST_VERSION)-universal-macosx.tar.gz

ncbi-blast-$(BLAST_VERSION)-universal-macosx.tar.gz:
	$(CURL) "ftp://ftp.ncbi.nlm.nih.gov/blast/executables/blast+/LATEST/ncbi-blast-$(BLAST_VERSION)-universal-macosx.tar.gz"
