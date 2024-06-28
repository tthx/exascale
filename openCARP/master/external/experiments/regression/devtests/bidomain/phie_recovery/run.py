#!/usr/bin/env python

"""
Test phie recovery in some nodes above a simple slab.

Problem Setup
=============

This example defines a thin cuboid domain (units in microns):

.. math::
    -1500  \leq x \leq 1500

    -2500 \leq y \leq  2500

    - 500 \leq z \leq   500

Run a modomain simulation in a cuboid portion of tissue and recover the :math:`phi_e` signals
above the corners of the geometry. Run the simulation with the same settings in
postprocessing mode to recover :math:`phi_e` based on the previous
simulation. Investigate the difference of the two simulation modes (i.e. experiment "0" [normal run]
and experiment "4" [postprocess only]).

.. image:: /images/phie_recovery_setup.png
    :scale: 60%
    :align: center

As with other examples, add the ``--visualize`` option to automatically load
the results in meshalyzer:

.. code-block:: bash

    ./run.py --visualize
"""
import os
import sys
import numpy as np
from datetime   import date
from shutil     import copyfile

from carputils.carpio import igb
from carputils import ep
from carputils import mesh
from carputils import settings
from carputils import testing
from carputils import tools

EXAMPLE_DESCRIPTIVE_NAME = 'Phie Recovery'
EXAMPLE_AUTHOR = 'Anton Prassl <anton.prassl@medunigraz.at>'
EXAMPLE_DIR = os.path.dirname(__file__)

isPy2 = True
if sys.version_info.major > 2:
    isPy2 = False
    xrange = range

def parser():
    parser = tools.standard_parser()
    group  = parser.add_argument_group('experiment specific options')

    group.add_argument('--sourceModel',
                        default='monodomain',
                        choices=ep.MODEL_TYPES,
                        help='pick type of electrical source model')
    group.add_argument('--propagation',
                        default = 'R-D',
                        choices = ep.PROP_TYPES,
                        help    =  'pick propagation driver, either R-D, R-E- '
                                   '(eikonal no diffusion) or R-E+ (eikonal with diffusion).')
    group.add_argument('--dx3D',
                        type    = float,
                        default = 200.,
                        help    = 'Discretization of volumentric elements (microns). Default: 200')
    group.add_argument('--method',
                        default  = 1,
                        type     = int,
                        help     = 'Method for recovering phie with monodomain runs')
    group.add_argument('--dt',
                        type=float,
                        default=25,
                        help='Time step size (us). Default: 25')
    group.add_argument('--tend',
                        type    = float,
                        default = 30,
                        help    = 'Duration of simulation (ms). Default: 30')
    return parser



def setupGeometry(dx3D):
    # Generate mesh (units are mm)
    x     = np.ceil(3/(dx3D/1000))*(dx3D/1000) # 5 cm
    y     = np.ceil(5/(dx3D/1000))*(dx3D/1000) # 3 cm
    z     = np.ceil(1/(dx3D/1000))*(dx3D/1000) # 1 cm (thinner in z-direction)
    # mxDim = np.max([x, y, z])+1

    geom  = mesh.Block(size = (x, y, z), resolution = dx3D/1000.)

    # Specify bath
    # geom.set_bath([.5*(mxDim-x), .5*(mxDim-y), .5*(mxDim-z)]) # specify bath

    # Set fibre angle to 0, sheet angle to 0
    geom.set_fibres(90, 90, 90, 90)

    # Generate and return base name
    return mesh.generate(geom)


def get_tissue_bbox(filename):
    # read data from simulation
    block   = mesh.Mesh()
    block.read_points(  filename + '.pts')
    block.read_elements(filename + '.elem')
    pts     = block.points() * 1000.    # mm to um
    elems   = block.elements()
    elemIDs = block.element_IDs()

    tissueIDs = np.where(elemIDs == 1)
    tissueIDs = np.squeeze(np.asarray(tissueIDs))

    unique_pts = set()
    for i_elem in tissueIDs:
        unique_pts.update(block.element(i_elem).nodes)

    list_unique_pts = list(unique_pts)
    del unique_pts, tissueIDs, elemIDs, elems

    ll = list()
    ur = list()
    sz = list()
    for index in xrange(3):
        ll.append(np.min(pts[list_unique_pts,index]))
        ur.append(np.max(pts[list_unique_pts,index]))
        sz.append(ur[index]-ll[index])

    return ll, ur, sz



def plot_traces(job, sourceModel, phieFile):

    geomfile = os.path.join(job.ID, 'block_i')
    datafile = os.path.join(job.ID, 'vm.igb')
    view     = os.path.join(EXAMPLE_DIR, 'vm_view.mshz')

    # Call meshalyzer
    job.meshalyzer(geomfile, datafile, view)

    igbobj = igb.IGBFile(os.path.join(job.ID, phieFile + '.igb'))
    header = igbobj.header()
    data   = igbobj.data()
    igbobj.close()

    # reshape data
    num_traces = header.get('x')
    num_tsteps = header.get('t')
    inc_t = header.get('inc_t')
    dim_t = header.get('dim_t')

    # allow plots from unfinished simulations
    if len(data) / num_traces < num_tsteps:
        num_tsteps = len(data) / num_traces
        dim_t = (num_tsteps - 1) * inc_t
        data = np.resize(data, num_tsteps * num_traces)

    data = data.reshape(num_tsteps, num_traces).T
    t = np.linspace(0, dim_t, num_tsteps)


    from matplotlib import pyplot as plt
    fig = plt.figure(dpi=200)
    fig.suptitle('{} - Traces'.format(phieFile))
    plt.plot(t, data[0,:].T, 'r-', label='trace 0')
    plt.plot(t, data[1,:].T, 'g-', label='trace 1')
    plt.plot(t, data[2,:].T, 'b-', label='trace 2')
    plt.plot(t, data[3,:].T, 'k-', label='trace 3')
    plt.xlabel('t (ms)')
    plt.ylabel('U (mV)')
    plt.legend()
    plt.grid(True)
    fig.savefig(os.path.join(job.ID, phieFile + '.png'))
    plt.show(block=False)
    return


def jobID(args):
    """
    Generate name of top level output directory.
    """
    today = date.today()

    tpl = '{}_{}_{}_{}um_{}dt_np{}'
    return tpl.format(today.isoformat(), args.sourceModel, args.propagation,
                      int(args.dx3D), int(args.dt), args.np)


@tools.carpexample(parser, jobID)
def run(args, job):

    # create cubic tissue/bath mesh
    meshname   = setupGeometry(args.dx3D)
    ll, ur, sz = get_tissue_bbox(meshname)


    # Get basic command line, including solver options
    cmd = tools.carp_cmd(os.path.join(EXAMPLE_DIR, 'carp.par'))

    # determine model type
    cmd += ep.model_type_opts(args.sourceModel)


    cmd += ['-simID',                job.ID,
            '-meshname',             meshname,
            '-dt',                   args.dt,
            '-tend',                 args.tend,
            '-gridout_i',            3,
            '-gridout_e',            3,
            '-num_stim',             2,
            # ground
            '-stimulus[0].x0',       ur[0]-args.dx3D,
            '-stimulus[0].y0',       ur[1]-args.dx3D,
            '-stimulus[0].z0',       ur[2]-args.dx3D,
            '-stimulus[0].xd',       args.dx3D,
            '-stimulus[0].yd',       args.dx3D,
            '-stimulus[0].zd',       args.dx3D,
            # second stimulus
            '-stimulus[1].stimtype', 0,
            '-stimulus[1].name',     'TRANSMEMBRANE_I_STIM',
            '-stimulus[1].x0',       ll[0],
            '-stimulus[1].y0',       ll[1],
            '-stimulus[1].z0',       ll[2],
            '-stimulus[1].xd',       args.dx3D,
            '-stimulus[1].yd',       args.dx3D,
            '-stimulus[1].zd',       args.dx3D,
            '-stimulus[1].strength', 100,
            '-stimulus[1].duration', 1,
            '-stimulus[1].start',    0,
            # phie recovery options applied during simulation
            '-phie_rec_ptf',         os.path.join('meshes', 'ecg'),
            '-phie_rec_meth',        args.method]
    cmd_bkp = copy.deepcopy(cmd)

    # define phie recovery locations
    if not settings.cli.dry:
        with open(os.path.join("meshes", "ecg.pts"), "w") as fid:
            fid.write('4\n')  # number of lead positions
            fid.write('%7.2f %7.2f %7.2f\n' % (ll[0], ll[1], ur[2] + sz[2]))
            fid.write('%7.2f %7.2f %7.2f\n' % (ur[0], ll[1], ur[2] + sz[2]))
            fid.write('%7.2f %7.2f %7.2f\n' % (ur[0], ur[1], ur[2] + sz[2]))
            fid.write('%7.2f %7.2f %7.2f\n' % (ll[0], ur[1], ur[2] + sz[2]))


    # run simulation with phie recovery during simulation
    job.carp(cmd)

    # do visualization
    if not settings.cli.dry:
        if args.visualize and not settings.platform.BATCH:
            # copy ecg file into working directory
            copyfile(os.path.join("meshes", "ecg.pts"), os.path.join(job.ID, "ecg.pts"))
            plot_traces(job, args.sourceModel, 'phie_recovery')


    # === postprocessing mode =================================================
    pp_cmd  = cmd_bkp
    pp_cmd += ['-experiment',           4,
               '-post_processing_opts', 1,
               '-ppID',                 'postprocess',
               '-phie_recovery_file',   'phie_recovery_pp']


    # run postprocessing
    job.carp(pp_cmd)
    copyfile(os.path.join(job.ID, "postprocess", "phie_recovery_pp.igb"), os.path.join(job.ID, "phie_recovery_pp.igb"))

    # Do visualization
    if not settings.cli.dry:
        if args.visualize and not settings.platform.BATCH:
            # copy ecg file into working directory
            copyfile(os.path.join("meshes", "ecg.pts"), os.path.join(job.ID, "ecg.pts"))
            plot_traces(job, args.sourceModel, 'phie_recovery_pp')

    return



# Define some tests
__tests__ = []
desc = ('')


desc = ('Phie recovery during simulation and as postprocessing step on single core (using FE mass and stiffness '
        'matrices)')
test = testing.Test('serial_recv_meth_1', run, ['--np', 1, '--method', 1],
                    description = desc,
                    refdir      = 'serial_recv_meth_1',
                    tags        = [testing.tag.FAST,
                                   testing.tag.SERIAL])

# phie recovery of specified electrode positions on single core
test.add_filecmp_check('phie_recovery.igb',    testing.max_error, 0.01)
test.add_filecmp_check('phie_recovery_pp.igb', testing.max_error, 0.01)
__tests__.append(test)

# -----------------------------------------------------------------------------
desc = ('Phie recovery during simulation and as postprocessing step on multiple cores (using FE mass and '
        'stiffness ')
test = testing.Test('parallel_recv_meth_1', run, ['--np', 4, '--method', 1],
                    description = desc,
                    refdir      = 'serial_recv_meth_1',
                    tags        = [testing.tag.FAST,
                                   testing.tag.PARALLEL])

# phie recovery of specified electrode positions in parallel
test.add_filecmp_check('phie_recovery.igb',    testing.max_error, 0.01)
test.add_filecmp_check('phie_recovery_pp.igb', testing.max_error, 0.01)
test.disable_reference_generation()
__tests__.append(test)

if __name__ == '__main__':
    run()
