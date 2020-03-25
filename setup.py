"""See README.md for package documentation."""

from io import open
from os.path import dirname, join, exists
from os import path, environ
import sys
from distutils.command.build_ext import build_ext
from setuptools import setup, Extension, find_namespace_packages

# get the version, we cannot import _version, because that would import
# __init__.py, which would import the cython-compiled code. But that has
# not been compiled yet so it would fail. So import only _version.py
filename = join(dirname(__file__), 'kivy_garden', 'collider', '_version.py')
locals = {}
with open(filename, "rb") as fh:
    exec(compile(fh.read(), filename, 'exec'), globals(), locals)
__version__ = locals['__version__']

URL = 'https://github.com/kivy-garden/collider'  # <-- change this


platform = sys.platform

# detect Python for android project (http://github.com/kivy/python-for-android)
# or kivy-ios (http://github.com/kivy/kivy-ios)
ndkplatform = environ.get('NDKPLATFORM')
if ndkplatform is not None and environ.get('LIBLINK'):
    platform = 'android'
kivy_ios_root = environ.get('KIVYIOSROOT', None)
if kivy_ios_root is not None:
    platform = 'ios'

# There are issues with using cython at all on some platforms;
# exclude them from using or declaring cython.

# This determines whether Cython specific functionality may be used.
can_use_cython = True
# This sets whether or not Cython gets added to setup_requires.
declare_cython = False

if platform in ('ios', 'android'):
    # NEVER use or declare cython on these platforms
    print('Not using cython on %s' % platform)
    can_use_cython = False
else:
    declare_cython = True

src_path = build_path = dirname(__file__)

with open(path.join(src_path, 'README.md'), encoding='utf-8') as f:
    long_description = f.read()


class FlowerBuildExt(build_ext, object):

    def __new__(cls, *a, **kw):
        # Note how this class is declared as a subclass of distutils
        # build_ext as the Cython version may not be available in the
        # environment it is initially started in. However, if Cython
        # can be used, setuptools will bring Cython into the environment
        # thus its version of build_ext will become available.
        # The reason why this is done as a __new__ rather than through a
        # factory function is because there are distutils functions that check
        # the values provided by cmdclass with issublcass, and so it would
        # result in an exception.
        # The following essentially supply a dynamically generated subclass
        # that mix in the cython version of build_ext so that the
        # functionality provided will also be executed.
        if can_use_cython:
            from Cython.Distutils import build_ext as cython_build_ext
            build_ext_cls = type(
                'FlowerBuildExt', (FlowerBuildExt, cython_build_ext), {})
            return super(FlowerBuildExt, cls).__new__(build_ext_cls)
        else:
            return super(FlowerBuildExt, cls).__new__(cls)

    def finalize_options(self):
        retval = super(FlowerBuildExt, self).finalize_options()
        global build_path
        if (self.build_lib is not None and exists(self.build_lib) and
                not self.inplace):
            build_path = self.build_lib
        return retval

    def build_extensions(self):
        compiler = self.compiler.compiler_type
        if compiler == 'msvc':
            args = []
        else:
            args = ["-O3", '-fno-strict-aliasing', '-Wno-error']
        for ext in self.extensions:
            ext.extra_compile_args = args
        super(FlowerBuildExt, self).build_extensions()


cmdclass = {'build_ext': FlowerBuildExt}

libraries = []
library_dirs = []
include_dirs = []

if can_use_cython:
    mod_suffix = '.pyx'
else:
    mod_suffix = '.c'

mods = ['collider/_collider']

ext_modules = [Extension(
    'kivy_garden.' + src_file.replace('/', '.'),
    sources=[join(
        src_path, 'kivy_garden', *(src_file + mod_suffix).split('/'))],
    libraries=libraries,
    include_dirs=include_dirs,
    library_dirs=library_dirs)
             for src_file in mods]

for e in ext_modules:
    e.cython_directives = {"embedsignature": True, 'language_level': 3}

setup_requires = []
if declare_cython:
    setup_requires.append('cython')

setup(
    name='kivy_garden.collider',
    version=__version__,
    description='Collides a point with a space defined by a curve.',
    long_description=long_description,
    long_description_content_type='text/markdown',
    url=URL,
    author='Kivy',
    author_email='kivy@kivy.org',
    classifiers=[
        'Development Status :: 4 - Beta',
        'Intended Audience :: Developers',
        'Topic :: Software Development :: Libraries',
        'License :: OSI Approved :: MIT License',
        'Programming Language :: Python :: 3.5',
        'Programming Language :: Python :: 3.6',
        'Programming Language :: Python :: 3.7',
        'Programming Language :: Python :: 3.8',
    ],
    keywords='Kivy kivy-garden',

    packages=find_namespace_packages(include=['kivy_garden.*']),
    setup_requires=setup_requires,
    install_requires=[],
    extras_require={
        'dev': ['pytest>=3.6', 'wheel', 'pytest-cov', 'pytest-asyncio',
                'sphinx_rtd_theme'],
        'ci': ['coveralls', 'pycodestyle'],
    },
    package_data={},
    data_files=[],
    entry_points={},
    cmdclass=cmdclass,
    ext_modules=ext_modules,
    project_urls={
        'Bug Reports': URL + '/issues',
        'Source': URL,
    },
)
