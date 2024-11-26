CC = gcc
CFLAGS = -Wall -Wextra -Wno-implicit-fallthrough -std=gnu17 -fPIC -O2
LDFLAGS = -Wl,--wrap=malloc -Wl,--wrap=calloc -Wl,--wrap=realloc -Wl,--wrap=reallocarray -Wl,--wrap=free -Wl,--wrap=strdup -Wl,--wrap=strndup

.PHONY: all clean

all: libnand.so

nand.o: nand.c nand.h
	$(CC) $(CFLAGS) -c $< -o $@

memory_tests.o: memory_tests.c memory_tests.h
	$(CC) $(CFLAGS) -c $< -o $@

libnand.so: nand.o memory_tests.o
	$(CC) -shared $(LDFLAGS) $^ -o $@

clean:
	rm -f *.o libnand.so
