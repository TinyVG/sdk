TARGETS=win-x64 linux-x64 linux-arm64 linux-arm osx-x64 # osx-arm64

default:
	dotnet build -r linux-x64 -p:PublishSingleFile=true -p:SelfContained=true

publish: $(TARGETS)
	cp -r release/win-x64/* ../../../release/x86_64-windows/bin/
	cp -r release/linux-x64/* ../../../release/x86_64-linux/bin/
	cp -r release/osx-x64/* ../../../release/x86_64-macos/bin/
	cp -r release/linux-arm64/* ../../../release/aarch64-linux/bin/
	# cp -r release/osx-arm64/* ../../../release/aarch64-macos/bin/

$(TARGETS): svg2tvgt.cs svg2tvgt.csproj
	dotnet publish -r $@ -c Release -p:PublishSingleFile=true -p:SelfContained=true
	mkdir -p "release/$@"
	cp -r bin/Release/net5.0/$@/publish/* "release/$@/"

.PHONY: $(TARGETS)
.SUFFIXES: