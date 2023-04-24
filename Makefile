# Note: Last built with version 2.0.15 of Emscripten

# TODO: Emit a file showing which version of emcc and SQLite was used to compile the emitted output.
# TODO: Create a release on Github with these compiled assets rather than checking them in
# TODO: Consider creating different files based on browser vs module usage: https://github.com/vuejs/vue/tree/dev/dist

# I got this handy makefile syntax from : https://github.com/mandel59/sqlite-wasm (MIT License) Credited in LICENSE
# To use another version of Sqlite, visit https://www.sqlite.org/download.html and copy the appropriate values here:
SQLITE_BUILD_PATH = ../sqlite/container-build
SQLITE_SRC_PATH = ../sqlite/src

# Note that extension-functions.c hasn't been updated since 2010-02-06, so likely doesn't need to be updated
EXTENSION_FUNCTIONS = extension-functions.c
EXTENSION_FUNCTIONS_URL = https://www.sqlite.org/contrib/download/extension-functions.c?get=25
EXTENSION_FUNCTIONS_SHA1 = c68fa706d6d9ff98608044c00212473f9c14892f

EMCC=emcc

SQLITE_COMPILATION_FLAGS = \
	-O1 \
	-g \
	-DSQLITE_OMIT_LOAD_EXTENSION \
	-DSQLITE_DISABLE_LFS \
	-DSQLITE_ENABLE_FTS3 \
	-DSQLITE_ENABLE_FTS3_PARENTHESIS \
	-DSQLITE_THREADSAFE=0 \
	-DSQLITE_ENABLE_NORMALIZE \
	-DSQLITE_JIT

# When compiling to WASM, enabling memory-growth is not expected to make much of an impact, so we enable it for all builds
# Since tihs is a library and not a standalone executable, we don't want to catch unhandled Node process exceptions
# So, we do : `NODEJS_CATCH_EXIT=0`, which fixes issue: https://github.com/sql-js/sql.js/issues/173 and https://github.com/sql-js/sql.js/issues/262
EMFLAGS = \
	--memory-init-file 0 \
	-s RESERVED_FUNCTION_POINTERS=64 \
	-s ALLOW_TABLE_GROWTH=1 \
	-s EXPORTED_FUNCTIONS=@src/exported_functions.json \
	-s EXPORTED_RUNTIME_METHODS=@src/exported_runtime_methods.json \
	-s SINGLE_FILE=0 \
	-s NODEJS_CATCH_EXIT=0 \
	-s NODEJS_CATCH_REJECTION=0

EMFLAGS_ASM = \
	-s WASM=0

EMFLAGS_ASM_MEMORY_GROWTH = \
	-s WASM=0 \
	-s ALLOW_MEMORY_GROWTH=1

EMFLAGS_WASM = \
	-s WASM=1 \
	-s ALLOW_MEMORY_GROWTH=1 \
	-Wl,--growable-table \
	-Wl,--export-table

EMFLAGS_OPTIMIZED= \
	-Oz \
	-flto \
	--closure 1

EMFLAGS_DEBUG = \
	-s ASSERTIONS=1 \
	-g \
	-O1

BITCODE_FILES = out/sqlite3.o out/extension-functions.o out/compiler.o out/runtime.o out/operations.o out/analysis.o out/inMemorySort.o

OUTPUT_WRAPPER_FILES = src/shell-pre.js src/shell-post.js

SOURCE_API_FILES = src/api.js

EMFLAGS_PRE_JS_FILES = \
	--pre-js src/api.js

EXPORTED_METHODS_JSON_FILES = src/exported_functions.json src/exported_runtime_methods.json

all: optimized debug worker

.PHONY: debug
debug: dist/sql-asm-debug.js dist/sql-wasm-debug.js

dist/sql-asm-debug.js: $(BITCODE_FILES) $(OUTPUT_WRAPPER_FILES) $(SOURCE_API_FILES) $(EXPORTED_METHODS_JSON_FILES)
	$(EMCC) $(EMFLAGS) $(EMFLAGS_DEBUG) $(EMFLAGS_ASM) $(BITCODE_FILES) $(EMFLAGS_PRE_JS_FILES) -o $@
	mv $@ out/tmp-raw.js
	cat src/shell-pre.js out/tmp-raw.js src/shell-post.js > $@
	rm out/tmp-raw.js

dist/sql-wasm-debug.js: $(BITCODE_FILES) $(OUTPUT_WRAPPER_FILES) $(SOURCE_API_FILES) $(EXPORTED_METHODS_JSON_FILES)
	$(EMCC) $(EMFLAGS) $(EMFLAGS_DEBUG) $(EMFLAGS_WASM) $(BITCODE_FILES) $(EMFLAGS_PRE_JS_FILES) -o $@
	mv $@ out/tmp-raw.js
	cat src/shell-pre.js out/tmp-raw.js src/shell-post.js > $@
	rm out/tmp-raw.js

.PHONY: optimized
optimized: dist/sql-asm.js dist/sql-wasm.js dist/sql-asm-memory-growth.js

dist/sql-asm.js: $(BITCODE_FILES) $(OUTPUT_WRAPPER_FILES) $(SOURCE_API_FILES) $(EXPORTED_METHODS_JSON_FILES)
	$(EMCC) $(EMFLAGS) $(EMFLAGS_OPTIMIZED) $(EMFLAGS_ASM) $(BITCODE_FILES) $(EMFLAGS_PRE_JS_FILES) -o $@
	mv $@ out/tmp-raw.js
	cat src/shell-pre.js out/tmp-raw.js src/shell-post.js > $@
	rm out/tmp-raw.js

dist/sql-wasm.js: $(BITCODE_FILES) $(OUTPUT_WRAPPER_FILES) $(SOURCE_API_FILES) $(EXPORTED_METHODS_JSON_FILES)
	$(EMCC) $(EMFLAGS) $(EMFLAGS_OPTIMIZED) $(EMFLAGS_WASM) $(BITCODE_FILES) $(EMFLAGS_PRE_JS_FILES) -o $@
	mv $@ out/tmp-raw.js
	cat src/shell-pre.js out/tmp-raw.js src/shell-post.js > $@
	rm out/tmp-raw.js

dist/sql-asm-memory-growth.js: $(BITCODE_FILES) $(OUTPUT_WRAPPER_FILES) $(SOURCE_API_FILES) $(EXPORTED_METHODS_JSON_FILES)
	$(EMCC) $(EMFLAGS) $(EMFLAGS_OPTIMIZED) $(EMFLAGS_ASM_MEMORY_GROWTH) $(BITCODE_FILES) $(EMFLAGS_PRE_JS_FILES) -o $@
	mv $@ out/tmp-raw.js
	cat src/shell-pre.js out/tmp-raw.js src/shell-post.js > $@
	rm out/tmp-raw.js

# Web worker API
.PHONY: worker
worker: dist/worker.sql-asm.js dist/worker.sql-asm-debug.js dist/worker.sql-wasm.js dist/worker.sql-wasm-debug.js

dist/worker.sql-asm.js: dist/sql-asm.js src/worker.js
	cat $^ > $@

dist/worker.sql-asm-debug.js: dist/sql-asm-debug.js src/worker.js
	cat $^ > $@

dist/worker.sql-wasm.js: dist/sql-wasm.js src/worker.js
	cat $^ > $@

dist/worker.sql-wasm-debug.js: dist/sql-wasm-debug.js src/worker.js
	cat $^ > $@

# Building it this way gets us a wrapper that _knows_ it's in worker mode, which is nice.
# However, since we can't tell emcc that we don't need the wasm generated, and just want the wrapper, we have to pay to have the .wasm generated
# even though we would have already generated it with our sql-wasm.js target above.
# This would be made easier if this is implemented: https://github.com/emscripten-core/emscripten/issues/8506
# dist/worker.sql-wasm.js: $(BITCODE_FILES) $(OUTPUT_WRAPPER_FILES) src/api.js src/worker.js $(EXPORTED_METHODS_JSON_FILES) dist/sql-wasm-debug.wasm
# 	$(EMCC) $(EMFLAGS) $(EMFLAGS_OPTIMIZED) -s ENVIRONMENT=worker -s $(EMFLAGS_WASM) $(BITCODE_FILES) --pre-js src/api.js -o out/sql-wasm.js
# 	mv out/sql-wasm.js out/tmp-raw.js
# 	cat src/shell-pre.js out/tmp-raw.js src/shell-post.js src/worker.js > $@
# 	#mv out/sql-wasm.wasm dist/sql-wasm.wasm
# 	rm out/tmp-raw.js

# dist/worker.sql-wasm-debug.js: $(BITCODE_FILES) $(OUTPUT_WRAPPER_FILES) src/api.js src/worker.js $(EXPORTED_METHODS_JSON_FILES) dist/sql-wasm-debug.wasm
# 	$(EMCC) -s ENVIRONMENT=worker $(EMFLAGS) $(EMFLAGS_DEBUG) -s ENVIRONMENT=worker -s WASM_BINARY_FILE=sql-wasm-foo.debug $(EMFLAGS_WASM) $(BITCODE_FILES) --pre-js src/api.js -o out/sql-wasm-debug.js
# 	mv out/sql-wasm-debug.js out/tmp-raw.js
# 	cat src/shell-pre.js out/tmp-raw.js src/shell-post.js src/worker.js > $@
# 	#mv out/sql-wasm-debug.wasm dist/sql-wasm-debug.wasm
# 	rm out/tmp-raw.js

out/sqlite3.o: $(SQLITE_BUILD_PATH)/sqlite3.c
	mkdir -p out
	# Generate llvm bitcode
	$(EMCC) $(SQLITE_COMPILATION_FLAGS) -c $^ -o $@

# Since the extension-functions.c includes other headers in the sqlite_amalgamation, we declare that this depends on more than just extension-functions.c
out/extension-functions.o: sqlite-src/$(EXTENSION_FUNCTIONS)
	mkdir -p out
	$(EMCC) $(SQLITE_COMPILATION_FLAGS) -I$(SQLITE_SRC_PATH) -I$(SQLITE_BUILD_PATH) -c $^ -o $@

out/compiler.o: $(SQLITE_SRC_PATH)/vdbeJIT/compiler.cc
	mkdir -p out
	$(EMCC) $(SQLITE_COMPILATION_FLAGS) -I$(SQLITE_SRC_PATH) -I$(SQLITE_BUILD_PATH) -c $^ -o $@

out/runtime.o: $(SQLITE_SRC_PATH)/vdbeJIT/runtime.c
	mkdir -p out
	$(EMCC) $(SQLITE_COMPILATION_FLAGS) -I$(SQLITE_SRC_PATH) -I$(SQLITE_BUILD_PATH) -c $^ -o $@

out/inMemorySort.o: $(SQLITE_SRC_PATH)/vdbeJIT/inMemorySort.c
	mkdir -p out
	$(EMCC) $(SQLITE_COMPILATION_FLAGS) -I$(SQLITE_SRC_PATH) -I$(SQLITE_BUILD_PATH) -c $^ -o $@

out/operations.o: $(SQLITE_SRC_PATH)/vdbeJIT/operations.cc
	mkdir -p out
	$(EMCC) $(SQLITE_COMPILATION_FLAGS) -I$(SQLITE_SRC_PATH) -I$(SQLITE_BUILD_PATH) -c $^ -o $@

out/analysis.o: $(SQLITE_SRC_PATH)/vdbeJIT/analysis.cc
	mkdir -p out
	$(EMCC) $(SQLITE_COMPILATION_FLAGS) -I$(SQLITE_SRC_PATH) -I$(SQLITE_BUILD_PATH) -c $^ -o $@

## cache
cache/$(EXTENSION_FUNCTIONS):
	mkdir -p cache
	curl -LsSf '$(EXTENSION_FUNCTIONS_URL)' -o $@

sqlite-src/$(EXTENSION_FUNCTIONS): cache/$(EXTENSION_FUNCTIONS)
	mkdir -p sqlite-src
	echo '$(EXTENSION_FUNCTIONS_SHA1)  ./cache/$(EXTENSION_FUNCTIONS)' > cache/check.txt
	sha1sum -c cache/check.txt
	cp 'cache/$(EXTENSION_FUNCTIONS)' $@

.PHONY: clean
clean:
	rm -f out/* dist/*