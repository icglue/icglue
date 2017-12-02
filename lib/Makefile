# debug ?
DEBUG?=0
# compiler
CC=gcc

LIBRARY=icglue.so

# source files
SOURCES= \
	icglue.c \
	ig_data.c \

############################################################################
# libs to include, executable, linker
LIBS=glib-2.0 tcl

ifeq ($(CC),gcc)
CXX=g++
endif
ifeq ($(CC),clang)
CXX=clang++
endif

LD=$(CC)

# flags
ifeq ($(DEBUG),0)
OPTFLAGS+=-O2
else
OPTFLAGS+=-ggdb
endif

############################################################################
# flags and co
COMPILEFLAGS=-c -Wall -fpic -I.
CFLAGS=$(COMPILEFLAGS) -std=gnu99 $(OPTFLAGS) $(CPPFLAGS)
CXXFLAGS=$(COMPILEFLAGS) $(OPTFLAGS) $(CPPFLAGS)
LDFLAGS=$(OPTFLAGS) -shared

CFLAGS+=$(shell pkg-config --cflags $(LIBS))
CXXFLAGS+=$(shell pkg-config --cflags $(LIBS))
LDFLAGS+=$(shell pkg-config --libs $(LIBS))

OBJDIR=obj

CSOURCES=$(filter %.c,$(SOURCES))
CXXSOURCES=$(filter %.cpp,$(SOURCES))
OBJECTS=$(CSOURCES:%.c=$(OBJDIR)/%.o)
OBJECTS+=$(CXXSOURCES:%.cpp=$(OBJDIR)/%.o)
DEPS=$(CSOURCES:%.c=$(OBJDIR)/%.d)
DEPS+=$(CXXSOURCES:%.cpp=$(OBJDIR)/%.d)

############################################################################
# rules
.PHONY: all
all: $(LIBRARY)

-include $(OBJECTS:.o=.d)

$(LIBRARY): $(OBJECTS) Makefile
	$(LD) $(LDFLAGS) $(OBJECTS) -o $@

$(OBJDIR)/%.o: %.c Makefile | $(OBJDIR)
	$(CC) -MM $(CFLAGS) $*.c > $(OBJDIR)/$*.d
	sed -i -e "s/\\(.*\\.o:\\)/$(OBJDIR)\\/\\1/" $(OBJDIR)/$*.d
	$(CC) $(CFLAGS) $*.c -o $(OBJDIR)/$*.o

$(OBJDIR)/%.o: %.cpp Makefile | $(OBJDIR)
	$(CXX) -MM $(CXXFLAGS) $*.cpp > $(OBJDIR)/$*.d
	sed -i -e "s/\\(.*\\.o:\\)/$(OBJDIR)\\/\\1/" $(OBJDIR)/$*.d
	$(CXX) $(CXXFLAGS) $*.cpp -o $(OBJDIR)/$*.o

$(OBJDIR):
	mkdir -p $@

clean:
	rm -f $(OBJECTS) $(DEPS)
	rm -f $(LIBRARY)
	rm -rf $(OBJDIR)
	rm -f *.moc.cpp

