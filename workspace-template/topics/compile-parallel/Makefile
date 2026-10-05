# Makefile: builds the three pi programs into build/ with the Cray compiler wrapper.
#
#   make                      build/pi_serial build/pi_omp build/pi_mpi
#   make -B CC="$(which cc)"  what job.sbatch runs (inside the job, after module reset)
#   make -n                   show the commands only (fine on the harness node)
#   make cuda                 build/pi_cuda with nvcc for the A40 (sm_86); stretch, see TAILOR.md
#
# On Delta `cc` is the Cray PE wrapper (craype) around GCC 14; it adds the cray-mpich include
# and link flags itself, so there is no mpicc here. A tool shell without the Cray paths may find
# /usr/bin/cc instead: then pass CC= explicitly, or use the absolute fallback below.

CC := $(shell which cc 2>/dev/null)
ifeq ($(strip $(CC)),)
CC := /opt/cray/pe/craype/default/bin/cc
endif
NVCC ?= nvcc
CFLAGS ?= -O2 -std=gnu11 -Wall
OMPFLAGS ?= -fopenmp
CUDA_ARCH ?= sm_86
BUILD := build

.PHONY: all cuda clean

all: $(BUILD)/pi_serial $(BUILD)/pi_omp $(BUILD)/pi_mpi

$(BUILD):
	mkdir -p $(BUILD)

$(BUILD)/pi_serial: src/pi_serial.c | $(BUILD)
	$(CC) $(CFLAGS) -o $@ $<

$(BUILD)/pi_omp: src/pi_omp.c | $(BUILD)
	$(CC) $(CFLAGS) $(OMPFLAGS) -o $@ $<

$(BUILD)/pi_mpi: src/pi_mpi.c | $(BUILD)
	$(CC) $(CFLAGS) -o $@ $<

cuda: $(BUILD)/pi_cuda

$(BUILD)/pi_cuda: src/pi_cuda.cu | $(BUILD)
	$(NVCC) -O2 -arch=$(CUDA_ARCH) -o $@ $<

clean:
	rm -rf $(BUILD)
