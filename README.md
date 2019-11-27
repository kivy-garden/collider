[![Coverage Status](https://coveralls.io/repos/github/kivy-garden/collider/badge.svg?branch=master)](https://coveralls.io/github/kivy-garden/collider?branch=master)
[![Github Build Status](https://github.com/kivy-garden/collider/workflows/Garden%20flower/badge.svg)](https://github.com/kivy-garden/collider/actions)

See https://kivy-garden.github.io/collider/ for the rendered collider docs.

Please see the garden [instructions](https://kivy-garden.github.io) for how to use kivy garden flowers.

Collider
===============

See http://kivy-garden.github.io/garden.collider/index.html for html docs.

The collider module contains classes which can be used to test membership
of a point in some space. See individual class documentation for details.

For example, using the Collide2DPoly class we can test whether points fall
within a general polygon, e.g. a simple triangle::

    >>> collider = Collide2DPoly([10., 10., 20., 30., 30., 10.],\
                                 cache=True)
    >>> (0.0, 0.0) in collider
    False
    >>> (20.0, 20.0) in collider
    True

Install
---------

To install with pip::

    pip install kivy_garden.collider

To build or re-build locally::

    PYTHONPATH=.:$PYTHONPATH python setup.py build_ext --inplace

Or to install as editable (package is installed, but can be edited in its original location)::

    pip install -e .

CI
--

Every push or pull request run the [GitHub Action](https://github.com/kivy-garden/flower/actions) CI.
It tests the code on various OS and also generates wheels that can be released on PyPI upon a
tag. Docs are also generated and uploaded to the repo as well as artifacts of the CI.

TODO
-------

* add your code

Contributing
--------------

Check out our [contribution guide](CONTRIBUTING.md) and feel free to improve the flower.

License
---------

This software is released under the terms of the MIT License.
Please see the [LICENSE.txt](LICENSE.txt) file.

How to release
===============

* update `__version__` in `kivy-garden/collider/__init__.py` to the latest version.
* update `CHANGELOG.md` and commit the changes
* call `git tag -a x.y.z -m "Tagging version x.y.z"`
* for each python version you want to release call `python setup.py bdist_wheel`, which generates the wheels. Call once `python setup.py sdist` to generate the sdist. They are saved in the dist/* directory
* Make sure the dist directory contains the files to be uploaded to pypi and call `twine check dist/*`
* then call `twine upload dist/*` to upload to pypi.
* call `git push origin master --tags` to push the latest changes and the tags to github.
