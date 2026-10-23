# tessarchy-portal (file chooser portal backend) and the GTK3 module that
# routes plain GtkFileChooserDialogs through the portal.
#   make [O=build/portal]          build
#   make install DESTDIR=... PREFIX=/usr
O ?= .
PREFIX ?= /usr
CFLAGS ?= -O2
CFLAGS += -Wall -Wextra -Wno-unused-parameter
PKG_CONFIG ?= pkg-config
here := $(dir $(lastword $(MAKEFILE_LIST)))

all: $(O)/tessarchy-portal $(O)/libtessarchy-filechooser.so

$(O)/tessarchy-portal: $(here)tessarchy-portal.c
	@mkdir -p $(O)
	$(CC) $(CPPFLAGS) $(CFLAGS) $(LDFLAGS) -o $@ $< $$($(PKG_CONFIG) --cflags --libs gio-2.0 gio-unix-2.0)

$(O)/libtessarchy-filechooser.so: $(here)filechooser-module.c
	@mkdir -p $(O)
	$(CC) $(CPPFLAGS) $(CFLAGS) $(LDFLAGS) -shared -fPIC -o $@ $< $$($(PKG_CONFIG) --cflags --libs gtk+-3.0)

install: all
	install -Dm755 $(O)/tessarchy-portal $(DESTDIR)$(PREFIX)/lib/tessarchy/tessarchy-portal
	install -Dm755 $(O)/libtessarchy-filechooser.so $(DESTDIR)$(PREFIX)/lib/gtk-3.0/modules/libtessarchy-filechooser.so
	install -Dm644 $(here)tessarchy.portal $(DESTDIR)$(PREFIX)/share/xdg-desktop-portal/portals/tessarchy.portal
	install -Dm644 $(here)tessarchy-portals.conf $(DESTDIR)$(PREFIX)/share/xdg-desktop-portal/tessarchy-portals.conf
	install -Dm644 $(here)org.freedesktop.impl.portal.desktop.tessarchy.service $(DESTDIR)$(PREFIX)/share/dbus-1/services/org.freedesktop.impl.portal.desktop.tessarchy.service

.PHONY: all install
