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

import os
import numpy as np
from datetime import date

from carputils import settings
from carputils import bench
from carputils import testing
from carputils import tools

def parser():
    parser = tools.standard_parser()
    parser.add_argument('--model',
                        default='DrouhardRoberge',
                        help='select IMP model')
    return parser

@tools.carpexample(parser)
def run(args,job):
    imp = args.model#bench.imps()
    #for imp in imps:
      #print(imp)
    if not os.path.exists('{}'.format(os.path.join(imp))):
      os.makedirs('{}'.format(os.path.join(imp)))
    cmd = [settings.execs.BENCH,
      '--imp={}'.format(imp)]
    cmd += ['--fout={}'.format(os.path.join(imp,imp)),
      '--bin',
      '--no-trace',
      '--validate',
      '--duration', 1000,
      '+',
      '-log_view',
      '-log_view_memory',
      '-log_view_gpu_time',
      '-mat_type', 'aijkokkos',
      '-vec_type', 'kokkos']

    job.mpi(cmd)

if __name__ == '__main__':
    run()
