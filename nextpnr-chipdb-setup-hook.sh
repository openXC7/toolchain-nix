addNextpnrChipdbPaths() {
  addToSearchPath NEXTPNR_XILINX_CHIPDB_DIR "$1/"
}

addEnvHooks "$targetOffset" addNextpnrChipdbPaths
