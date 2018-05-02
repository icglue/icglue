#
#   ICGlue is a Tcl-Library for scripted HDL generation
#   Copyright (C) 2017-2018  Andreas Dixius, Felix Neumärker
#
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see <https://www.gnu.org/licenses/>.
#

# ===============================================================================
#
#  Description: Common makefile for applications and libraries
#
#===============================================================================

#-------------  name of the executable binary  ---------------------------------
EXECUTALBE      ?= icglue.so

#-------------  name of the target (can also be a library *.{a,so})  -----------
TARGET          ?= $(EXECUTALBE)

#-------------  directory of the target  ---------------------------------------
TARGET_DIR      ?= ./binaries

#-------------  list of all source files  --------------------------------------
SOURCES         ?= *.c *.cc

#-------------  directory of source files --------------------------------------
SOURCE_DIR      ?= .

#-------------  pkg-config for includes and libs  ------------------------------
PKG_CFG_LIBS    ?= glib-2.0 tcl

#-------------  directories of includes  ---------------------------------------
INC_DIR         ?= .

#-------------  directories of libraries  --------------------------------------
LIB_DIR         ?=

#-------------  library linkflags  ---------------------------------------------
LIBS            ?=

#-------------  directory of the dependency  -----------------------------------
DEPS_DIR        ?= ./.deps

#-------------  path to doxyfile  ----------------------------------------------
DOXYFILE        ?= ./doxy/Doxyfile
DOXY_DOCPATH    ?= ./doc

#-------------  directory of the asm files -------------------------------------
CREATE_ASM      ?= NO

#-------------  directory of the asm files -------------------------------------
ASM_DIR         ?= ./.asm

#-------------  use linktime optimization  -------------------------------------
USE_LTO         ?= NO

# ------------  compiler flags  ------------------------------------------------
WARNFLAGS       ?= -Wall
OPTFLAGS        ?= -O2 -fdata-sections -ffunction-sections
ARCHFLAGS       ?= -mtune=native -march=native
CFLAGS          ?= -std=gnu99
CXXFLAGS        ?=
CPPFLAGS        := $(addprefix -D, $(DEFS) $(PREDEFS)) $(addprefix -I, $(INC_DIR))
LDFLAGS         ?= -Wl,-O1 -Wl,--gc-sections
ASMFLAG         ?= -adhln

# ------------  build-tools  ---------------------------------------------------
GP              ?=
CC              := $(GP)gcc
CXX             := $(GP)g++
LD              := $(GP)ld
OD              := $(GP)objdump
STRIP           := $(GP)strip
AR              := $(GP)ar
LN              := ln -sf
RM              := rm -f
RMDIR           := rmdir
MKDIR           := mkdir -p

ifeq ($(USE_LTO), YES)
  OPTFLAGS      := -flto $(OPTFLAGS)
  LDFLAGS       := -flto -fuse-linker-plugin $(ALL_LDFLAGS)
endif

ifeq ($(suffix $(TARGET)), .so)
  CFLAGS        := -fpic $(CFLAGS)
  CXXFLAGS      := -fpic $(CXXFLAGS)
  LDFLAGS       := -shared $(LDFLAGS)
endif

ALL_CFLAGS      := $(WARNFLAGS) $(OPTFLAGS) $(ARCHFLAGS) $(CFLAGS) $(CPPFLAGS)
ALL_CXXFLAGS    := $(WARNFLAGS) $(OPTFLAGS) $(ARCHFLAGS) $(CXXFLAGS) $(CPPFLAGS)
ALL_LDFLAGS     := $(LDFLAGS)

#pkg-config
ifneq ($(PKG_CFG_LIBS),)
  ALL_CFLAGS    += $(shell pkg-config --cflags $(PKG_CFG_LIBS))
  ALL_CXXFLAGS  += $(shell pkg-config --cflags $(PKG_CFG_LIBS))
  ALL_LDFLAGS   += $(shell pkg-config --libs $(PKG_CFG_LIBS))
endif

# ------------  generate the names of the source/object files  -----------------
ALL_SOURCES      = $(wildcard $(SOURCE_DIR)/$(SOURCES))
BASENAMES        = $(basename $(ALL_SOURCES:$(SOURCE_DIR)/%=%))
OBJECTS          = $(addprefix $(TARGET_DIR)/, $(addsuffix .o, $(BASENAMES)))
DEPS             = $(addprefix $(DEPS_DIR)/, $(addsuffix .d, $(BASENAMES)))

# ------------ basic compile rule ----------------------------------------------

.DEFAULT_GOAL := all

all: $(TARGET_DIR)/$(TARGET)

$(DEPS_DIR):
	@$(MKDIR) $(DEPS_DIR)

$(TARGET_DIR):
	@$(MKDIR) $(TARGET_DIR)

$(ASM_DIR):
ifeq ($(CREATE_ASM), YES)
	@$(MKDIR) $(ASM_DIR)
endif


$(DEPS_DIR)/%.d: $(SOURCE_DIR)/%.c Makefile | $(DEPS_DIR)
	@$(CC) -MM -E $(CPPFLAGS) $< | perl -p -e 's#[^:]*:#$(TARGET_DIR)/$$&#' > $@
	@$(LN) $*.d $(DEPS_DIR)/$*.dep

$(DEPS_DIR)/%.d: $(SOURCE_DIR)/%.cc Makefile | $(DEPS_DIR)
	@$(CXX) -MM -E $(CPPFLAGS) $< | perl -p -e 's#[^:]*:#$(TARGET_DIR)/$$&#' > $@
	@$(LN) $*.d $(DEPS_DIR)/$*.dep

-include ${DEPS:.d=.dep}

$(TARGET_DIR)/%.o: $(SOURCE_DIR)/%.c $(DEPS_DIR)/%.d | $(TARGET_DIR) $(ASM_DIR)
ifeq ($(CREATE_ASM), YES)
	$(CC) $(ALL_CFLAGS) -g -c $< -o $@ -Wa,$(ASMFLAG)=$(ASM_DIR)/$*.s
else
	$(CC) $(ALL_CFLAGS) -g -c $< -o $@
endif

$(TARGET_DIR)/%.o: $(SOURCE_DIR)/%.cc $(DEPS_DIR)/%.d | $(TARGET_DIR) $(ASM_DIR)
ifeq ($(CREATE_ASM), YES)
	$(CXX) $(ALL_CXXFLAGS) -g -c $< -o $@ -Wa,$(ASMFLAG)=$(ASM_DIR)/$*.s
else
	$(CXX) $(ALL_CXXFLAGS) -g -c $< -o $@
endif

$(TARGET_DIR)/%.so: $(OBJECTS)
	$(CC) $(WARNFLAGS) $(LDFLAGS) -o $@ $(OBJECTS)

$(TARGET_DIR)/%.a: $(OBJECTS)
	$(AR) rcs $@ $(OBJECTS)

$(TARGET_DIR)/$(EXECUTALBE): $(OBJECTS)
	$(CC) $(WARNFLAGS) $(ARCHFLAGS) $(ALL_LDFLAGS) -o $@ $(OBJECTS) $(addprefix -L, $(LIB_DIR)) $(LIBS)

run: $(TARGET_DIR)/$(EXECUTALBE)
	$(TARGET_DIR)/$(EXECUTALBE) $(RUNPARAMS)

dump: $(TARGET_DIR)/$(TARGET)
	$(OD) -dxt -S $(TARGET_DIR)/$(TARGET)

release: $(TARGET_DIR)/$(TARGET)
	$(STRIP) -g $(TARGET_DIR)/$(TARGET)

strip-all: $(TARGET_DIR)/$(EXECUTABLE)
	$(STRIP) -s $(TARGET_DIR)/$(EXECUTABLE)

doc:
	doxygen $(DOXYFILE) |grep -i warning; true

viewdoc:
	@$${BROWSER:-firefox} $(DOXY_DOCPATH)/html/index.html >/dev/null 2>&1 &

clean:
	-@$(RM) $(addprefix $(TARGET_DIR)/, *.o $(TARGET)) $(ASM_DIR)/*.s $(addprefix $(DEPS_DIR)/, *.d *.dep)
	-@$(RMDIR) $(DEPS_DIR) $(TARGET_DIR) $(ASM_DIR) 2>/dev/null; true
	-@$(RM) -rf $(addprefix ./$(DOXY_DOCPATH)/, html latex rtf man); true
	-@$(RMDIR) ./$(DOXY_DOCPATH) 2>/dev/null; true

uncrustify:
	@for f in *.c *.h ; do \
		uncrustify -c .uncrustify.cfg --replace --no-backup $$f ; \
	done


.SECONDARY: $(DEPS) $(OBJECTS) $(TARGET_DIR)/$(TARGET)

.PHONY: all run release strip-all doc viewdoc clean uncrustify

