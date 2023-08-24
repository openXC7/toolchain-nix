addPrjxrayPaths() {
  addToSearchPath PRJXRAY_PYTHON_DIR "$1/usr/share/python3/"
}

addEnvHooks "$targetOffset" addPrjxrayPaths
