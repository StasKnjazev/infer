# Copyright (c) Facebook, Inc. and its affiliates.
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

SCRIPTS_DIR=..
JAR_FILES=$(wildcard java_targets/jar/*.jar)

define check_no_diff
	cmp $(1) $(2) >&2 || \
	(printf "ERROR: Output of $(1) differs from $(2)\n" >&2; exit 1)
endef

default: test-classdump

build-targets:
	make -C java_targets

test-classdump: build-targets
	python3 $(SCRIPTS_DIR)/classdump.py --output $(SCRIPTS_DIR)/test/classdump_out $(JAR_FILES)
	@$(foreach jarfile,$(notdir $(JAR_FILES)),$(call check_no_diff,$(SCRIPTS_DIR)/test/classdump_out/$(jarfile).classes,$(SCRIPTS_DIR)/test/classdump_exp/$(jarfile).classes.exp);)

clean:
	rm -rf java_targets/jar
