# Makefile for ALSA drain wrapper

CC = $(CROSS_COMPILE)gcc
CFLAGS = -shared -fPIC -O2 -Wall
LDFLAGS = -ldl

TARGET = libasound_nodrain.so
SOURCE = alsa_nodrain.c

all: $(TARGET)

$(TARGET): $(SOURCE)
	$(CC) $(CFLAGS) -o $(TARGET) $(SOURCE) $(LDFLAGS)

clean:
	rm -f $(TARGET)

install:
	mkdir -p $(DESTDIR)/usr/lib
	cp $(TARGET) $(DESTDIR)/usr/lib/

.PHONY: all clean install
