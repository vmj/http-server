NAME      = http-server
VERSION   = 1.0-SNAPSHOT
MODULE_ID = http.server

MAIN_CLASS = fi.linuxbox.http.Main

OTHER_CLASSES = module-info

DOCKER_TAG = vmj0/http-server-$(TARGET)-java9:$(VERSION)

#
# Use TARGET env var to switch custom runtime target.
# Possible targets are native (default), alpine, and linux.
#
# E.g. make dockerImage TARGET=alpine
#
TARGET ?= native

#
# Download and extract the target JDKs,
# then export following env vars with the correct directories.
#
NATIVE_JMODS ?= /Library/Java/JavaVirtualMachines/jdk-9.jdk/Contents/Home/jmods
ALPINE_JMODS ?= /Users/vmj/jdks/x64-musl/jdk-9/jmods
LINUX_JMODS ?= /Users/vmj/jdks/x64-linux/jdk-9/jmods

ifeq ($(TARGET),native)
#
# This is for building a custom runtime and running it directly
# (not in Docker).
#
TARGET_JMODS ?= $(NATIVE_JMODS)

else
ifeq ($(TARGET),alpine)
#
# This is for building a custom runtime for Alpine Linux and running it
# in Docker.
#
BASE_IMAGE = alpine:3.5
TARGET_JMODS ?= $(ALPINE_JMODS)

else
ifeq ($(TARGET),linux)
#
# This is for building a custom runtime for pretty much any glibc based
# Linux distro.  E.g. Debian would do, too: debian:stretch-slim
#
BASE_IMAGE = vbatts/slackware:14.2
TARGET_JMODS ?= $(LINUX_JMODS)

else
$(error Unsupported TARGET: $(TARGET); Use one of 'native', 'alpine', or 'linux')
endif
endif
endif

#
# Build directories
#
BUILD_DIR      = build
CLASSES_DIR    = $(BUILD_DIR)/classes/main
JMODS_DIR      = $(BUILD_DIR)/jmods
DOCKERFILE_DIR = $(BUILD_DIR)/dockerfile
DOCKER_DIR     = $(BUILD_DIR)/docker
JRE_DIR        = $(BUILD_DIR)/jre

#
# Source directories
#
SRC_DIR      = src
JAVA_SRC_DIR = $(SRC_DIR)/main/java

# The output Java module
ARTIFACT_FILE = $(JMODS_DIR)/$(NAME)-$(VERSION).jar
# The output custom runtime
CUSTOM_RUNTIME_DIR = $(JRE_DIR)/$(TARGET)
# The output Dockerfile
DOCKERFILE = $(DOCKERFILE_DIR)/$(TARGET)

# Turn the class names to paths
SRC_FILES   = $(subst .,/,$(MAIN_CLASS) $(OTHER_CLASSES))

# Turn the paths to .class and .java file names (with full path)
CLASS_FILES = $(patsubst %,$(CLASSES_DIR)/%.class,$(SRC_FILES))
JAVA_FILES  = $(patsubst %,$(JAVA_SRC_DIR)/%.java,$(SRC_FILES))

.PHONY: classes classesRun jar jarRun jre jreRun dockerfile dockerImage dockerRun

help:
	@echo USAGE: make action [TARGET=target]
	@echo
	@echo Actions:
	@echo
	@echo "  classes                                                 "
	@echo "    Compiles the Java source files to class files.        "
	@echo "  classesRun                                              "
	@echo "    Runs the application from the class files.            "
	@echo "  jar                                                     "
	@echo "    Builds the modular JAR from the class files.          "
	@echo "  jarRun                                                  "
	@echo "    Runs the application from the modular JAR.            "
	@echo "  jre [TARGET=native|alpine|linux]                        "
	@echo "    Builds custom runtime for TARGET.                     "
	@echo "  jreRun [TARGET=native]                                  "
	@echo "    Runs the application from the custom runtime.         "
	@echo "  dockerfile [TARGET=alpine|linux]                        "
	@echo "    Creates the Dockerfile for TARGET.                    "
	@echo "  dockerImage [TARGET=alpine|linux]                       "
	@echo "    Creates the Docker image for TARGET.                  "
	@echo "  dockerRun [TARGET=alpine|linux]                         "
	@echo "    Runs the application in the TARGET specific container."
	@echo
	@echo Influential environment variables:
	@echo
	@echo "  NATIVE_JMODS                                          "
	@echo "    Full path the the jmods directory of native target. "
	@echo "  ALPINE_JMODS                                          "
	@echo "    Full path the the jmods directory of alpine target. "
	@echo "  LINUX_JMODS                                           "
	@echo "    Full path the the jmods directory of linux target.  "

clean:
	-@rm -rf $(BUILD_DIR)

classes: $(CLASS_FILES)
jar: $(ARTIFACT_FILE)
jre: $(CUSTOM_RUNTIME_DIR)
dockerfile: $(DOCKERFILE)

classesRun: classes
	-java --module-path $(CLASSES_DIR) -m $(MODULE_ID)/$(MAIN_CLASS)

jarRun: jar
	-java --module-path $(JMODS_DIR) -m $(MODULE_ID)

jreRun: jre
ifneq ($(TARGET),native)
	$(error only native target makes sense for running the custom runtime outside Docker)
endif
	-$(CUSTOM_RUNTIME_DIR)/bin/java -m $(MODULE_ID)

$(CLASSES_DIR)/%.class: $(JAVA_SRC_DIR)/%.java
	@rm -rf $(CLASSES_DIR)
	@mkdir -p $(CLASSES_DIR)
	javac -d $(CLASSES_DIR) $(JAVA_FILES)

$(ARTIFACT_FILE): $(CLASS_FILES)
	@rm -rf $(JMODS_DIR)
	@mkdir -p $(JMODS_DIR)
	jar --create --file $@ --main-class $(MAIN_CLASS) -C $(CLASSES_DIR) .

$(CUSTOM_RUNTIME_DIR): $(ARTIFACT_FILE) $(TARGET_JMODS)
	@rm -rf $(CUSTOM_RUNTIME_DIR)
	jlink --module-path $(JMODS_DIR):$(TARGET_JMODS) \
	      --strip-debug --vm server --compress 2 \
	      --class-for-name --no-header-files --no-man-pages \
	      --dedup-legal-notices=error-if-not-same-content \
	      --add-modules $(MODULE_ID) \
	      --output $@

$(DOCKERFILE): Dockerfile.in
ifeq ($(TARGET),native)
	$(error only alpine and linux targets make sense for Docker)
endif
	@mkdir -p $(DOCKERFILE_DIR)
	sed -e 's BASE_IMAGE $(BASE_IMAGE) ' Dockerfile.in >$(DOCKERFILE)

dockerImage: dockerfile jre
ifeq ($(TARGET),native)
	$(error only alpine and linux targets make sense for Docker)
endif
	@rm -rf $(DOCKER_DIR)
	@mkdir -p $(DOCKER_DIR)
	cp -a $(CUSTOM_RUNTIME_DIR) $(DOCKER_DIR)/jre
	cp $(DOCKERFILE) $(DOCKER_DIR)/Dockerfile
	(cd $(DOCKER_DIR) && docker build --tag $(DOCKER_TAG) .)

dockerRun: dockerImage
	docker run --rm -it -p9000:9000 $(DOCKER_TAG)
