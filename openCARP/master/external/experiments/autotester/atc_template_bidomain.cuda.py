#!/usr/bin/env python3
#
# This file is part of openCARP
# (see https://www.openCARP.org).
#
# The openCARP project licenses this file to you under the 
# Apache License, Version 2.0 (the "License"); 
# you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.
#

"""
This file generates the file `bidomain.atc` located at `experiments/regression/devtests/bidomain`.

`bidomain.atc` describes the regression tests run by autotester for the bidomain simulations.
"""

import os
import sys
import shutil
import base64
import argparse

from string import Template

from carputils import settings
from carputils import testing

parser = argparse.ArgumentParser()

parser.add_argument('--keep-output',
                    action='store_true',
                    help='Do not delete temporary simulation output')

parser.add_argument('--quick',
                    action='store_true',
                    help='Ignore long tests')

parser.add_argument('--flavor',
                    type=str, default='petsc',
                    choices=['petsc', 'ginkgo'],
                    help='openCARP flavor')

args = parser.parse_args()

# Get name of directory containing the current file
dirname, filename = os.path.split(os.path.abspath(__file__))
# Get parent directory of the current file
parentpath = os.path.abspath(os.path.join(dirname, os.pardir))
# Insert "regression" directory to PYTHONPATH
sys.path.insert(0,os.path.join(parentpath, 'regression'))

print('\nTest Env: Python {}.{}.{}'.format(sys.version_info.major, sys.version_info.minor, sys.version_info.micro))
print('\nopenCARP flavor: ', args.flavor)
print('\nKeep tests outputs:', args.keep_output, '\n')

if args.quick:
    # Select tests which are not tagged as LONG or MEDIUM
    tests_tags = [testing.tag.MEDIUM, testing.tag.LONG]
    tests_invert = True
else:
    tests_tags = []
    tests_invert = False

# Retrieve all tests and print a list
# Take only tests from devtests.bidomain
tests_to_run = list(testing.find_multi(['devtests.bidomain'],
                                        name=None,
                                        tags=tests_tags,
                                        combine=any,
                                        invert=tests_invert))
    
if len(tests_to_run) == 0:
    print('No tests were found matching the specified parameters.')
    sys.exit(1)

suite = testing.TestSuite(tests_to_run)

# If a directory named 'meshes' already exists, it is backed up at another location to avoid deleting it during testing.
atc_template_header = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<atc>
<test name="Backup meshes" group="openCARP-Bidomain">
    <description format="markdown">Back ups a potential existing meshes directory, which would be overwritten by tests</description>
    <call>
      <command>mv meshes/* meshes_backup/ 2> /dev/null || true</command>
    </call>
  </test> 
'''

# First part of a test definition: run the simulation
atc_template_test_header = '''  
  <test name="$name" group="openCARP-Bidomain">
    <description format="markdown">This test fails if $name is bigger than the tolerance</description>
    <call>
      <command>python3 $dirname/regression/$modulerelpath $argv $flavorargs --ID _test_$name --overwrite-behaviour overwrite --CARP-opts='+ -mat_type aijcusparse -vec_type cuda'</command>
    </call>
    <validations>'''

# Middle part of a test definition: compare result file with reference file 
atc_template_validation = '''
      <validation>
        <variables>
          <variable name="result_folder">_test_$name</variable>
          <variable name="reference_folder">$dirname/regression-references/devtests/$refdir/$refdirname</variable>
          <variable name="tol">$tolerance</variable>
        </variables>
        <description>Checking maximum error between the test result and the reference for $name</description>
        <call>
          <command>python3 $dirname/autotester/max_error.py --tol $tol$ --result $result_folder$/$resfile --reference $reference_folder$/$reffile</command>
        </call>
      </validation>'''

# Last part of a test definition: delete the folder containing the results of the simulation
# unless keep-output option was set
if args.keep_output:
    atc_template_test_footer = '''
    </validations>
  </test>'''
else:
    atc_template_test_footer = '''
      <validation>
        <variables>
          <variable name="result_folder">_test_$name</variable>
        </variables>
        <description>Remove test folder</description>
        <call>
          <command>rm -r $result_folder$</command>
        </call>
      </validation>
    </validations>
  </test>'''

if args.keep_output:
    atc_template_footer = '''
</atc>'''
else:
    atc_template_footer = '''
  <test name="Remove meshes" group="openCARP-Bidomain">
    <description format="markdown">Remove meshes created for testing</description>
    <call>
      <command>rm -r meshes</command>
    </call>
  </test>  
</atc>'''

# Open atc file describing autotester regression tests for bidomain simulations
file = open(parentpath+'/regression/devtests/bidomain/bidomain.atc', 'w')
file.write(atc_template_header)
atc_test_header = Template(atc_template_test_header)
atc_validation = Template(atc_template_validation)
atc_test_footer = Template(atc_template_test_footer)

# Define flavor arguments
flavor_args = ''
if args.flavor == 'petsc':
    flavor_args = '--flavor petsc'
elif args.flavor == 'ginkgo':
    flavor_args = '--flavor ginkgo'

# Write each regression test in atc file
for test in suite.tests:
    test_name = test.module.split('.')[-2] + '-' + test.name
    file.write(atc_test_header.safe_substitute(dirname=parentpath, # 'Experiments' directory 
               name=test_name, # Name of the test
               modulerelpath=test.module.replace('.', '/') + '.py', # Path to `run.py` relatively to the regression folder
               flavorargs=flavor_args,
               argv=' '.join([str(e) for e in test._argv]))) # Command line arguments used for running the regression test

    # One test can have several reference files to check
    for check in test.checks:
        file.write(atc_validation.safe_substitute(dirname=parentpath, # 'Experiments' directory
            name=test_name, # Name of the test
            refdir=test.module.lstrip('devtests.'), # Path to directory containing reference solutions for this module, relatively to `devtests`
            refdirname=test.name if test._refdir is None else test._refdir, # Name of the directory containing test results
            tolerance=check.tolerance, # Error tolerance for this test
            reffile=check.filename, # Name of the file containing reference solution
            resfile=check.filename.rstrip('.gz'))) # Name of the file containing results of simulation

    file.write(atc_test_footer.safe_substitute(name=test_name))

file.write(atc_template_footer)
file.close()
