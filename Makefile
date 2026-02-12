GIT_REF := $(shell git rev-parse --abbrev-ref HEAD 2>/dev/null)@$(shell git rev-parse --short HEAD 2>/dev/null)

.PHONY: run build-apk analyze test

run:
	flutter run --dart-define=GIT_REF=$(GIT_REF)

build-apk:
	flutter build apk --release --dart-define=GIT_REF=$(GIT_REF)

analyze:
	flutter analyze

test:
	flutter test
