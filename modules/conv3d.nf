#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

// ----------------------------------------------------------------------------------------
// Processes
// ----------------------------------------------------------------------------------------

process copy_beamlog {
    executor = "local"
    input:
        val image_cube
        val evaluation_files

    output:
        val beamlog_dest, emit: beamlog

    script:
        image_cube_file = file(image_cube)
        beamlog_src = file("${evaluation_files}/SpectralCube_BeamLogs/beamlog*.i.*beam00.txt").first()
        beamlog_dest = image_cube_file.getParent() + "/beamlog." + image_cube_file.getBaseName() + ".txt"

        """
        #!/bin/bash

        cp $beamlog_src $beamlog_dest
        """
}

// Run Beamcon_3D for convolution
process beamcon {
    containerOptions = "${params.BEAMCON_CLUSTER_OPTIONS}"

    input:
        val image_cube
        val beamlog

    output:
        val cube_conv, emit: cube_conv

    script:
        file = file(image_cube)
        cube_conv = "${file.getParent()}/${file.getBaseName()}.total.${file.getExtension()}"

        """
        #!/bin/bash

        export SINGULARITY_TMPDIR=${params.SINGULARITY_TMPDIR}
        export SLURM_NTASKS=${params.BEAMCON_NTASKS}

	    srun -n ${params.BEAMCON_NTASKS} singularity exec --bind ${params.SCRATCH_ROOT}:${params.SCRATCH_ROOT} \
            ${params.SINGULARITY_CACHEDIR}/racstools_latest.sif \
            beamcon_3D ${image_cube} \
            --mode total \
            --bmaj ${params.BMAJ} --bmin ${params.BMIN} --bpa ${params.BPA} \
            -v
        """
}

// ----------------------------------------------------------------------------------------
// Workflow
// ----------------------------------------------------------------------------------------

workflow conv3d {
    take:
        cube
        evaluation_files

    main:
        copy_beamlog(cube, evaluation_files)
        beamcon(cube, copy_beamlog.out.beamlog)

    emit:
        cube_conv = beamcon.out.cube_conv
}

// ----------------------------------------------------------------------------------------
