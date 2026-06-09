BINARY  = podcast-player
SOURCE  = podcast-player.cob
COBC    = cobc
FLAGS   = -free -x

.PHONY: build run clean

build: $(BINARY)

$(BINARY): $(SOURCE)
	$(COBC) $(FLAGS) $(SOURCE) -o $(BINARY)

run: build
	TERM=xterm-256color ./$(BINARY)

clean:
	rm -f $(BINARY) feed.rss chapters.json
