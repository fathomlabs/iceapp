# VERSION numbers
POSTGRES_VERSION=9.4.1
POSTGRES_MAJOR_VERSION=9.4
LIBXML2_VERSION=2.9.1
OPENSSL_VERSION=1.0.1m

#path configuration
PREFIX=/Applications/Ice.app/Contents/Versions/postgres-$(POSTGRES_MAJOR_VERSION)
PATH=$(PREFIX)/bin:/bin:/usr/bin:/opt/local/bin

#compiler options
MACOSX_DEPLOYMENT_TARGET=10.7
CFLAGS:=$(CFLAGS) -mmacosx-version-min=10.7
CXXFLAGS:=$(CFLAGS) -mmacosx-version-min=10.7

export CFLAGS CXXFLAGS MACOSX_DEPLOYMENT_TARGET

# commands used for downloading and extracting sources
CURL=/usr/bin/curl -L10 --silent --show-error --remote-name
TAR=/usr/bin/tar xzf

all: postgresql
clean: clean-postgresql clean-openssl clean-libxml2

#########################
###### PostgreSQL #######
#########################

postgresql: $(PREFIX)/bin/psql

$(PREFIX)/bin/psql: postgresql-$(POSTGRES_VERSION)/GNUmakefile
	make -C "postgresql-$(POSTGRES_VERSION)" world
	make -C "postgresql-$(POSTGRES_VERSION)" install-world

# setting PATH is to make sure we find the right xml2-config
# the --with-includes and --with-libraries options are necessary so
# that postgres will be compiled and linked against our own versions
# of libraries like openssl, instead of system provided versions
postgresql-$(POSTGRES_VERSION)/GNUmakefile: $(PREFIX)/lib/libssl.dylib $(PREFIX)/lib/libxml2.dylib postgresql-$(POSTGRES_VERSION)/configure
	cd "postgresql-$(POSTGRES_VERSION)" && export PATH="$(PREFIX)/bin:$$PATH" && ./configure --prefix="$(PREFIX)" --with-includes="$(PREFIX)/include" --with-libraries="$(PREFIX)/lib" --enable-thread-safety --with-openssl --with-gssapi --with-bonjour --with-libxml --with-libxslt --with-perl --with-python --with-readline --with-uuid=e2fs --with-icu
# patch makefile to fix python linker flags
	cd postgresql-$(POSTGRES_VERSION)/src; mv Makefile.global Makefile.global.old; sed 's@^python_libspec.*@python_libspec = '"`python-config --ldflags`"'@' Makefile.global.old >Makefile.global

postgresql-$(POSTGRES_VERSION)/configure: postgresql-$(POSTGRES_VERSION).tar.bz2
	$(TAR) "postgresql-$(POSTGRES_VERSION).tar.bz2"
	mv postgresql-$(POSTGRES_VERSION)/GNUMakefile.in postgresql-$(POSTGRES_VERSION)/GNUMakefile.bk
	sed 's/\,doc /\,/g' postgresql-$(POSTGRES_VERSION)/GNUMakefile.bk > postgresql-$(POSTGRES_VERSION)/GNUMakefile.in
	touch $@

postgresql-$(POSTGRES_VERSION).tar.bz2:
	$(CURL) "https://ftp.postgresql.org/pub/source/v$(POSTGRES_VERSION)/postgresql-$(POSTGRES_VERSION).tar.bz2"

clean-postgresql:
	make -C "postgresql-$(POSTGRES_VERSION)" clean


#########################
####### OpenSSL #########
#########################

openssl: $(PREFIX)/lib/libssl.dylib

$(PREFIX)/lib/libssl.dylib: openssl-${OPENSSL_VERSION}/Makefile
	make -C openssl-${OPENSSL_VERSION}
	make -C openssl-${OPENSSL_VERSION} install_sw

openssl-${OPENSSL_VERSION}/Makefile: openssl-${OPENSSL_VERSION}/Configure
	cd openssl-${OPENSSL_VERSION} && ./Configure --prefix="${PREFIX}" darwin64-x86_64-cc zlib no-asm no-krb5 shared

openssl-${OPENSSL_VERSION}/Configure: openssl-${OPENSSL_VERSION}.tar.gz
	$(TAR) openssl-${OPENSSL_VERSION}.tar.gz
	touch $@

openssl-${OPENSSL_VERSION}.tar.gz:
	$(CURL) "https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz"

clean-openssl:
	rm -Rf "openssl-${OPENSSL_VERSION}"

#########################
######## LibXML2 ########
#########################

libxml2: $(PREFIX)/lib/libxml2.dylib

$(PREFIX)/lib/libxml2.dylib: libxml2-${LIBXML2_VERSION}/Makefile
	make -C libxml2-${LIBXML2_VERSION} install-exec
	make -C libxml2-${LIBXML2_VERSION}/include install
	touch $(PREFIX)/lib/libxml2.dylib

libxml2-${LIBXML2_VERSION}/Makefile: libxml2-${LIBXML2_VERSION}/configure
	cd libxml2-${LIBXML2_VERSION} && ./configure --prefix="$(PREFIX)" --disable-dependency-tracking

libxml2-${LIBXML2_VERSION}/configure: libxml2-${LIBXML2_VERSION}.tar.gz
	$(TAR) libxml2-${LIBXML2_VERSION}.tar.gz
	touch $@

libxml2-${LIBXML2_VERSION}.tar.gz:
	$(CURL) "ftp://xmlsoft.org/libxml2/libxml2-${LIBXML2_VERSION}.tar.gz"

clean-libxml2:
	rm -Rf "libxml2-$(LIBXML2_VERSION)"
