.PHONY: debug release clean clean-debug clean-release run

debug:
	cmake -B build-debug -G Ninja -DCMAKE_BUILD_TYPE=Debug
	ninja -C build-debug

release:
	cmake -B build-release -G Ninja -DCMAKE_BUILD_TYPE=Release
	ninja -C build-release

run: debug
	open build-debug/Applications/TextMate/TextMate.app

clean: clean-debug clean-release

clean-debug:
	rm -rf build-debug

clean-release:
	rm -rf build-release
