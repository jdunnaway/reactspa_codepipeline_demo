SHELL=/bin/bash
.EXPORT_ALL_VARIABLES:
.SHELLFLAGS = -uec
.PHONY: default build

default:
	echo "no default target"

build:
	mkdir build
	echo ${CODEBUILD_RESOLVED_SOURCE_VERSION} > build/version
	cd ..
	npm install
	npm run-script build