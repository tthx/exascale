#!/usr/bin/env python

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

from datetime import date
import os
from carputils import settings
from carputils import tools


def parser():

    parser = tools.standard_parser()

    parser.add_argument('--experiment', default='active',
                        choices=['active','passive'],
                        help='pick experiment type')
    parser.add_argument('--EP',  default='LuoRudy91',
                        help='pick electrophysiology model (featuring Cai) (see bench --list-imps)')
    parser.add_argument('--plugin', default='Stress_Land17',
                        help='pick stress model (see bench --list-imps for available stress plugins)')
    parser.add_argument('--duration', default='1000',
                        help='pick duration of experiment')
    parser.add_argument('--bcl', default='1000',
                        help='pick basic cycle length')

    return parser



@tools.carpexample(parser)
def run(args, job):

    imp = args.plugin
    if not os.path.exists('{}'.format(os.path.join(imp))):
        os.makedirs('{}'.format(os.path.join(imp)))

    # run bench with available ionic models
    cmd  = [settings.execs.BENCH,
            '--imp={}'.format(args.EP),
            '--plug-in={}'.format(args.plugin),
            '--duration', args.duration ]

    if args.experiment == 'passive':
        cmd += [ '--stim-curr',       0.0,
                 '--numstim',         0,
                 '--strain-rate',     150.,
                 '--strain',          0.2,
                 '--strain-time',     50.,
                 '--strain-dur',      20. ]

    else:
        cmd += [ '--stim-curr',      60.0,
                 '--numstim',        int(float(args.duration)/float(args.bcl)+1),
                 '--bcl',            args.bcl ]

    # Output options
    cmd += ['--fout={}'.format(os.path.join(imp, imp)),
            '--bin',
            '--no-trace',
            '--validate',
            '+',
            '-log_view',
            '-log_view_memory',
            '-log_view_gpu_time',
            '-mat_type', 'aij',
            '-vec_type', 'standard']

    job.mpi(cmd, 'Testing {}-{}'.format(args.EP,args.plugin))

if __name__ == '__main__':
    run()
