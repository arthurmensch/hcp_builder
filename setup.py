#! /usr/bin/env python
#
# Copyright (C) 2016 Arthur Mensch

import os
import sys

from setuptools import find_packages

DISTNAME = 'hcp_builder'
DESCRIPTION = "Download HCP rest + task data from the S3 repo, and runs the FSL GLM on time series."
LONG_DESCRIPTION = open('README.md').read()
MAINTAINER = 'Arthur Mensch'
MAINTAINER_EMAIL = 'arthur.mensch@m4x.org'
URL = 'https://gitlab.inria.fr/amensch/hcp_builder'
LICENSE = 'new BSD'
DOWNLOAD_URL = 'https://gitlab.inria.fr/amensch/hcp_builder'
VERSION = '0.1'


def configuration(parent_package='', top_path=None):
    if os.path.exists('MANIFEST'):
        os.remove('MANIFEST')

    from numpy.distutils.misc_util import Configuration
    config = Configuration(None, parent_package, top_path)

    config.set_options(ignore_setup_xxx_py=True,
                       assume_default_configuration=True,
                       delegate_options_to_subpackages=True,
                       quiet=True)

    config.add_subpackage('hcp_builder')

    return config


def setup_package():
    local_path = os.path.dirname(os.path.abspath(sys.argv[0]))

    os.chdir(local_path)
    sys.path.insert(0, local_path)

    from numpy.distutils.core import setup

    bash_files = [(d, [os.path.join(d, f) for f in files])
                   for d, folders, files in os.walk('glm_scripts')]

    setup(configuration=configuration,
          packages=find_packages(),
          name=DISTNAME,
          maintainer=MAINTAINER,
          include_package_data=True,
          maintainer_email=MAINTAINER_EMAIL,
          description=DESCRIPTION,
          license=LICENSE,
          url=URL,
          version=VERSION,
          data_files=bash_files,
          download_url=DOWNLOAD_URL,
          long_description=LONG_DESCRIPTION,
          zip_safe=False,  # the package can run out of an .egg file
          classifiers=[
              'Intended Audience :: Science/Research',
              'Intended Audience :: Developers',
              'License :: OSI Approved',
              'Programming Language :: C',
              'Programming Language :: Python',
              'Topic :: Software Development',
              'Topic :: Scientific/Engineering',
              'Operating System :: Microsoft :: Windows',
              'Operating System :: POSIX',
              'Operating System :: Unix',
              'Operating System :: MacOS',
              'Programming Language :: Python :: 3.5'
          ],
          )


if __name__ == "__main__":
    setup_package()
