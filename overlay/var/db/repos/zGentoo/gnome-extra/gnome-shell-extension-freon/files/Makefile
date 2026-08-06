INSTALL_PATH = ~/.local/share/gnome-shell/extensions
INSTALL_NAME = freon@UshakovVasilii_Github.yahoo.com

all: build

install: build
	rm -rf $(INSTALL_PATH)/$(INSTALL_NAME)
	mkdir -p $(INSTALL_PATH)/$(INSTALL_NAME)
	cp -R -p _build/* $(INSTALL_PATH)/$(INSTALL_NAME)
	rm -rf _build
	echo Installed in $(INSTALL_PATH)/$(INSTALL_NAME)

build: compile-schema
	rm -rf _build
	mkdir _build
	cp -R -p $(INSTALL_NAME)/* _build
	echo Build was successful

compile-schema: ./$(INSTALL_NAME)/schemas/org.gnome.shell.extensions.sensors.gschema.xml
	glib-compile-schemas $(INSTALL_NAME)/schemas

clean:
	rm -rf _build

uninstall:
	rm -rf $(INSTALL_PATH)/$(INSTALL_NAME)
