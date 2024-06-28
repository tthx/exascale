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
from carputils import settings
from carputils import tools

def parser():
    parser = tools.standard_parser()
    parser.add_argument('--model',
                        default='OHara',
                        help='select IMP model')
    parser.add_argument('--surface-to-volume',
                        default=0.5,
                        help='cell surface to cell volume ratio to be used to \
                              convert stimulus current to concentration change')
    parser.add_argument('--stim-species',
                        default='Ki:Cai',
                        help='concentrations that should be affected by stimuli, e.g. \'Ki:Cli\'') 
    parser.add_argument('--stim-ratios',
                        default='0.7:0.3',
                        help='proportions of stimlus current carried by each species, e.g. \'0.7:0.3\'')
    
    return parser


@tools.carpexample(parser)
def run(args,job):
    if not os.path.exists(f'{os.path.join(args.model)}'):
        os.makedirs(f'{os.path.join(args.model)}')

    # run bench with available ionic models
    cmd = [settings.execs.BENCH, f'--imp={args.model}']

    # Output options
    cmd += [f'--fout={os.path.join(args.model, args.model)}',
            '--duration', 1000,
            '--stim-assign', 'on',
            '--surface-to-volume', args.surface_to_volume,
            '--stim-species', args.stim_species,
            '--stim-ratios', args.stim_ratios,
            '--no-trace',
            '--validate',
            '+',
            '-log_view',
            '-log_view_memory',
            '-log_view_gpu_time',
            '-mat_type', 'aijkokkos',
            '-vec_type', 'kokkos']

    job.mpi(cmd)

if __name__ == '__main__':
    run()
