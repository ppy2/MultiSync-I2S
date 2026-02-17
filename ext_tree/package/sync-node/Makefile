CC = $(CROSS_COMPILE)gcc
CFLAGS = -O2 -Wall
TARGET = sync_node
SOURCE = sync_node.c

all: $(TARGET)

$(TARGET): $(SOURCE)
	$(CC) $(CFLAGS) -o $(TARGET) $(SOURCE)

clean:
	rm -f $(TARGET)

.PHONY: all clean
