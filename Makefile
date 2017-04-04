
BUILD_DIR=build
CLASSES_DIR=$(BUILD_DIR)/classes/main
JMODS_DIR=$(BUILD_DIR)/jmods
DOCKER_DIR=$(BUILD_DIR)/docker
JRE_DIR=$(BUILD_DIR)/jre

SRC_DIR=src
JAVA_SRC_DIR=$(SRC_DIR)/main/java

LINUX_JMODS=/usr/lib/jvm/java-9-openjdk-amd64/jmods
MACOS_JMODS=/Library/Java/JavaVirtualMachines/jdk-9.jdk/Contents/Home/jmods

assemble: $(JMODS_DIR)/http-server-1.0-SNAPSHOT.jar

$(JMODS_DIR)/http-server-1.0-SNAPSHOT.jar: $(CLASSES_DIR)/module-info.class $(CLASSES_DIR)/fi/linuxbox/http/Main.class
	rm -rf $(JMODS_DIR)
	mkdir -p $(JMODS_DIR)
	jar --create --file $(JMODS_DIR)/http-server-1.0-SNAPSHOT.jar --main-class fi.linuxbox.http.Main -C $(CLASSES_DIR) .

$(CLASSES_DIR)/module-info.class: $(JAVA_SRC_DIR)/module-info.java
	mkdir -p $(BUILD_DIR)
	javac -d $(CLASSES_DIR) $(JAVA_SRC_DIR)/module-info.java $(JAVA_SRC_DIR)/fi/linuxbox/http/Main.java

$(CLASSES_DIR)/fi/linuxbox/http/Main.class: $(JAVA_SRC_DIR)/fi/linuxbox/http/Main.java
	mkdir -p $(BUILD_DIR)
	javac -d $(CLASSES_DIR) $(JAVA_SRC_DIR)/module-info.java $(JAVA_SRC_DIR)/fi/linuxbox/http/Main.java

.PHONY=dockerImage
dockerImage: Dockerfile $(JRE_DIR)/linux
	rm -rf $(DOCKER_DIR)
	mkdir -p $(DOCKER_DIR)
	cp -a Dockerfile $(JRE_DIR)/linux $(DOCKER_DIR)
	(cd $(DOCKER_DIR) && docker build --tag vmj0/http-server:java9 .)


dockerRun: dockerImage
	docker run --rm -it -p9000:9000 vmj0/http-server:java9 sh

$(JRE_DIR)/linux: $(JMODS_DIR)/http-server-1.0-SNAPSHOT.jar
	rm -rf $(JRE_DIR)/linux
	jlink --module-path $(JMODS_DIR):$(LINUX_JMODS) --strip-debug --vm server --compress 2 --class-for-name --no-header-files --no-man-pages --add-modules http.server --output $(JRE_DIR)/linux

$(JRE_DIR)/macos: $(JMODS_DIR)/http-server-1.0-SNAPSHOT.jar
	rm -rf $(JRE_DIR)/macos
	jlink --module-path $(JMODS_DIR):$(MACOS_JMODS) --strip-debug --vm server --compress 2 --class-for-name --no-header-files --no-man-pages --add-modules http.server --output $(JRE_DIR)/macos
