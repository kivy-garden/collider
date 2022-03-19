"""The version of the package.

We need to provide a version file rather than placing the version in the
`__init__.py`, because we cannot import `__init__.py`
during a compilation because the cython code is not yet compiled so
importing `__init__.py` would fail.
But we need the version during the compilation step, so it is
declared externally here.
"""

__version__ = '0.1.2'
