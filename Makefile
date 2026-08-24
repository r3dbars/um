.PHONY: model test app dmg clean

model:
	./scripts/download-model.sh

test:
	swift test

app: model
	./scripts/package-app.sh

dmg: app
	./scripts/create-dmg.sh

clean:
	rm -rf .build dist DerivedData
