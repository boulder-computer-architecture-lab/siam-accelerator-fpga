import os, re, time
import numpy as np
from typing import Any

from pynq import Overlay, allocate
from pynq.lib.dma import DMA
from pynq import PL

from cdma import CDMA

class MVMKernel:
    def __init__(
        self,
        bitfile: str,
        matrix: Any,
        Npad: int, # padded matrix dimension used by RTL
        bram_base: int = 0x8000_0000, # fixed in hw
        word_width_bits: int = 128,   # fixed in hw
        element_width_bits: int = 32, # 16/32/64 (changes overlay)
        active_channels: int = 4,     # fixed in hw
        file_type: str = "npy",
        cdma_name: str = "axi_cdma_0",
        dma_prefix: str = "axi_dma",
        verbose: int = 0,
    ):
        self.bitfile = bitfile
        self.file_type = file_type
        self.verbose = verbose

        self.Npad = int(Npad)
        self.active_channels = int(active_channels)
        self.num_partitions = self.active_channels

        self.word_width_bits = int(word_width_bits)
        self.element_width_bits = int(element_width_bits)

        if self.Npad % self.active_channels != 0:
            raise ValueError(f"Npad={self.Npad} must be divisible by active_channels={self.active_channels}")

        if self.word_width_bits % self.element_width_bits != 0:
            raise ValueError(f"word_width_bits={self.word_width_bits} must be divisible by element_width_bits={self.element_width_bits}")

        if   self.element_width_bits == 16: self.np_dtype = np.float16
        elif self.element_width_bits == 32: self.np_dtype = np.float32
        elif self.element_width_bits == 64: self.np_dtype = np.float64
        else: raise ValueError(f"Unsupported element_width_bits={self.element_width_bits}")

        self.bytes_per_element = self.element_width_bits // 8
        self.bytes_per_word    = self.word_width_bits // 8
        self.elements_per_word = self.word_width_bits // self.element_width_bits

        self.num_rows          = self.Npad
        self.elements_per_row  = self.Npad
        self.rows_per_channel  = self.num_rows // self.active_channels

        if self.elements_per_row % self.elements_per_word != 0:
            raise ValueError(
                f"elements_per_row={self.elements_per_row} must be divisible by elements_per_word={self.elements_per_word}"
            )

        self.words_per_row = self.elements_per_row // self.elements_per_word
        self.bytes_per_row = self.words_per_row * self.bytes_per_word

        if self.elements_per_row % self.num_partitions != 0:
            raise ValueError(
                f"elements_per_row={self.elements_per_row} must be divisible by num_partitions={self.num_partitions}"
            )

        self.elements_per_partition = self.elements_per_row // self.num_partitions
        self.bytes_per_partition    = self.bytes_per_row // self.num_partitions

        self.bram_base = int(bram_base)
        partition_addr_width = self.bytes_per_partition.bit_length()
        partition_align = 1 << partition_addr_width
        self.partition_base = [
            self.bram_base + i * partition_align
            for i in range(self.num_partitions)
        ]

        if self.verbose:
            print("[kernel] dtype:", self.np_dtype)
            print("[kernel] Npad:", self.Npad)
            print("[kernel] channels:", self.active_channels)
            print("[kernel] rows_per_channel:", self.rows_per_channel)
            print("[kernel] elements_per_row:", self.elements_per_row)
            print("[kernel] elements_per_partition:", self.elements_per_partition)
            print("[kernel] bytes_per_partition:", self.bytes_per_partition)
            print("[kernel] partition_base:", [hex(x) for x in self.partition_base])

        # overlay / IP handles
        PL.reset()
        self.overlay = Overlay(self.bitfile, download=True)
        if not self.overlay.is_loaded():
            raise RuntimeError("Overlay download failed.")

        # CDMA for writing vector partitions
        if cdma_name not in self.overlay.ip_dict:
            raise RuntimeError(f"Could not find {cdma_name} in overlay.")
        self.cdma = CDMA(self.overlay.ip_dict[cdma_name])

        # DMAs (sorted by trailing index)
        self.dmas = [
            getattr(self.overlay, name)
            for name in sorted(
                self.overlay.ip_dict,
                key=lambda n: int(re.search(r"\d+$", n).group()) if re.search(r"\d+$", n) else 0
            )
            if name.startswith(dma_prefix)
        ]
        if len(self.dmas) < self.active_channels:
            raise RuntimeError(f"Found {len(self.dmas)} DMAs but need active_channels={self.active_channels}")
        self.dmas = self.dmas[:self.active_channels]

        # host-side backing for matrix (memmap)
        self.matrix_data = matrix.reshape(self.active_channels, self.rows_per_channel, self.elements_per_row)

        # allocate CMA buffers (result, vector partitions, matrix tile) with TILE_MODE
        self.result = allocate(shape=(self.active_channels, self.rows_per_channel), dtype=self.np_dtype)
        self.vector = allocate(shape=(self.num_partitions, self.elements_per_partition), dtype=self.np_dtype)

        self.TILE_MODE = False
        self.tile_rows = self.rows_per_channel
        self.matrix = None

        while self.tile_rows > 0:
            try:
                self.matrix = allocate(
                    shape=(self.active_channels, self.tile_rows, self.elements_per_row),
                    dtype=self.np_dtype
                )
                if self.verbose:
                    print(f"[kernel] matrix CMA allocation OK: tile_rows={self.tile_rows}")
                break
            except RuntimeError:
                self.TILE_MODE = True
                if self.verbose:
                    print(f"[kernel] matrix CMA allocation FAILED: tile_rows={self.tile_rows} -> halving")
                self.tile_rows //= 2

        if self.matrix is None:
            raise RuntimeError("Could not allocate any CMA buffer for matrix tiles.")

        # init buffers
        if not self.TILE_MODE:
            np.copyto(self.matrix, self.matrix_data)
        self.result.fill(0.0)
        self.result.flush()
        self.vector.flush()
        self.matrix.flush()
        print(f"[kernel] initialization done: TILE_MODE={self.TILE_MODE}")

    def send_vector(self):
        self.vector.flush()

        for p in range(self.num_partitions):
            self.cdma.transfer(
                source=self.vector[p],
                dest=self.partition_base[p],
                bytes_count=self.bytes_per_partition
            )
        #self.cdma.transfer(
        #    source=self.vector, 
        #    dest=self.bram_base, 
        #    bytes_count=self.bytes_per_row
        #)

    def matvec(self):
        # receive buffers first
        for ch, d in enumerate(self.dmas):
            d.recvchannel.transfer(self.result[ch])

        if not self.TILE_MODE:
            self.matrix.flush()
            for ch, d in enumerate(self.dmas):
                d.sendchannel.transfer(self.matrix[ch])
            for d in self.dmas:
                d.sendchannel.wait()
        else:
            src = self.matrix_data

            for tile_start in range(0, self.rows_per_channel, self.tile_rows):
                tile_end = min(tile_start + self.tile_rows, self.rows_per_channel)
                rows_this_tile = tile_end - tile_start

                # copy tile into CMA and flush
                np.copyto(
                    self.matrix[:, :rows_this_tile, :],
                    src[:, tile_start:tile_end, :]
                )
                self.matrix.flush()

                # send chunk
                for ch, d in enumerate(self.dmas):
                    d.sendchannel.transfer(self.matrix[ch, :rows_this_tile, :])

                for ch, d in enumerate(self.dmas):
                    d.sendchannel.wait()

        # wait for results
        for d in self.dmas:
            d.recvchannel.wait()

        self.result.invalidate()

        return self.result

    def close(self):
        try:
            self.result.freebuffer()
            self.vector.freebuffer()
            self.matrix.freebuffer()
        except Exception:
            pass

