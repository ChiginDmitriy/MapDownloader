# CPP Flags
CPP_FLAGS=-Werror -Wall -std=c++14 -x c++ -fmax-errors=1

# Sources directories
SRC_LIB_DIR=src/lib
SRC_LIB_INCLUDE_DIR=$(SRC_LIB_DIR)/include
SRC_RUNNER_DIR=src/runner

# Some src files lists
LIB_INCLUDE_FILES=$(shell find -L "$(SRC_LIB_INCLUDE_DIR)/img_concatenator" -type f -name '*.hpp' )

# Binary information
BIN_DIR=bin
LIB_NAME=ImgConcatenator
LIB_FILENAME=lib$(LIB_NAME).so
RUNNER_FILENAME=runner.out

# OpenCV
OPENCV_INCLUDE_DIR=/usr/local/include
OPENCV_DIR=/usr/local/lib
OPENCV_IMGCODECS_LIB_NAME=opencv_imgcodecs

# OpenCV include files list
OPENCV_INCLUDE_FILES=$(shell find -L "$(OPENCV_INCLUDE_DIR)" -type f -name '*.hpp')

# Phony targets

.PHONY: all lib runner clean_o clean 

all: runner

lib: $(BIN_DIR)/$(LIB_FILENAME)

runner: $(BIN_DIR)/$(RUNNER_FILENAME)


# Library
$(BIN_DIR)/ImgConcatenator.o: $(SRC_LIB_DIR)/ImgConcatenator.cpp           \
                              $(LIB_INCLUDE_FILES)                             \
                              $(OPENCV_INCLUDE_FILES)
	g++ $(CPP_FLAGS) -isystem "$(OPENCV_INCLUDE_DIR)" -fPIC -c $< -o $@

$(BIN_DIR)/$(LIB_FILENAME): $(BIN_DIR)/ImgConcatenator.o
	g++ -shared -Wl,-soname,$(LIB_FILENAME) $<                                       \
  -l$(OPENCV_IMGCODECS_LIB_NAME)                                                   \
  -o $@

# Runner
$(BIN_DIR)/runner.o: $(SRC_RUNNER_DIR)/runner.cpp                                  \
                     $(SRC_RUNNER_DIR)/aux.hpp
	g++ $(CPP_FLAGS) -c $< -o $@

$(BIN_DIR)/runner_aux.o: $(SRC_RUNNER_DIR)/aux.cpp                                 \
                         $(SRC_RUNNER_DIR)/aux.hpp                                 \
                         $(LIB_INCLUDE_FILES)
	g++ -isystem "$(SRC_LIB_INCLUDE_DIR)" $(CPP_FLAGS) -c $< -o $@

$(BIN_DIR)/$(RUNNER_FILENAME):   $(BIN_DIR)/runner.o                               \
                                 $(BIN_DIR)/runner_aux.o                           \
                               | $(BIN_DIR)/$(LIB_FILENAME)
	g++ -Wl,-rpath=. $^ $| -o $@


# Cleaning

clean_o:
	rm -vf bin/*.o bin/*.a

clean:
	rm -vfr bin/*

