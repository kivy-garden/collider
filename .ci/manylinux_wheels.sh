#!/bin/bash
set -e -x

yum -y install gcc gcc-c++ git make pkgconfig

cd /io
for PYBIN in /opt/python/*3*/bin; do
    if [[ $PYBIN != *"34"* ]]; then
        "${PYBIN}/pip" install --upgrade setuptools pip cython
        "${PYBIN}/pip" install kivy[base] --pre --extra-index-url https://kivy.org/downloads/simple/
        "${PYBIN}/pip" wheel --no-deps . -w dist/
    fi
done

for name in /io/dist/*.whl; do
    echo "Fixing $name"
    auditwheel repair --plat manylinux2010_x86_64 $name -w /io/dist/
done
