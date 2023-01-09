#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

// ----------------------------------------------------------------------------------------
// Processes
// ----------------------------------------------------------------------------------------

// This is required for the beamcon "robust" method.
process nan_to_zero {
    container = params.METADATA_IMAGE
    containerOptions = "--bind ${params.SCRATCH_ROOT}:${params.SCRATCH_ROOT}"

    input:
        val image_cube

    output:
        val image_cube_zeros, emit: image_cube_zeros

    script:
        filename = file(image_cube)
        image_cube_zeros = "${filename.getParent()}/${filename.getBaseName()}.zeros.${filename.getExtension()}"

        """
        #!python3

        import numpy as np
        from astropy.io import fits

        with fits.open("$image_cube", mode="readonly") as hdu:
            header = hdu[0].header
            data = np.nan_to_num(hdu[0].data)
            header['HISTORY'] = 'Replace NaN with zero'
        hdu = fits.PrimaryHDU(data=data, header=header)
        hdul = fits.HDUList([hdu])
        hdul.writeto("$image_cube_zeros", overwrite=True)
        """
}

process beamcon_setup {
    output:
        stdout emit: stdout
        val container, emit: container

    script:
        container = "${params.SINGULARITY_CACHEDIR}/racstools_latest.sif"

        """
        #!/bin/bash

        # check image exists
        [ ! -f ${container} ] && { singularity pull ${container} ${params.RACS_TOOLS_IMAGE}; }
        exit 0
        """
}
process beamcon_2D {
    containerOptions = "${params.BEAMCON_CLUSTER_OPTIONS}"

    input:
        val image
        val container

    output:
        stdout emit: stdout

    script:
        file = file(image)

        """
        #!/bin/bash

        export SINGULARITY_TMPDIR=${params.SINGULARITY_TMPDIR}
        export SLURM_NTASKS=${params.BEAMCON_NTASKS}

	    srun -n ${params.BEAMCON_NTASKS} singularity exec --bind ${params.SCRATCH_ROOT}:${params.SCRATCH_ROOT} \
            ${container} \
            beamcon_2D ${image} \
            --bmaj ${params.BMAJ} --bmin ${params.BMIN} --bpa ${params.BPA} \
            -v
        """
}

process extract_beamlog {
    container = params.METADATA_IMAGE
    containerOptions = "--bind ${params.SCRATCH_ROOT}:${params.SCRATCH_ROOT}"

    input:
        val evaluation_files

    output:
        stdout emit: stdout

    script:
        """
        python3 /app/get_file_in_compressed_folder.py \
            -p $evaluation_files \
            -f calibration-metadata-processing-logs \
            -k SpectralCube_BeamLogs/beamlog
        """
}

process copy_beamlog {
    executor = "local"
    input:
        val image_cube
        val evaluation_files
        val extract

    output:
        val beamlog, emit: beamlog

    script:
        cube = file(image_cube)
        beamlog_src = file("${evaluation_files}/SpectralCube_BeamLogs/beamlog*.i.*beam00.txt").first()
        beamlog_dest = cube.getParent() + "/beamlog." + cube.getBaseName() + ".txt"
        beamlog = file(beamlog_dest)

    if (!beamlog.exists())
        """
        #!/bin/bash

        cp $beamlog_src $beamlog_dest
        """
    else
        """
        #!/bin/bash
        echo $beamlog_dest
        """
}

process beamcon_3D {
    containerOptions = "${params.BEAMCON_CLUSTER_OPTIONS}"

    input:
        val image_cube
        val beamlog
        val container

    output:
        stdout emit: stdout

    script:
        file = file(image_cube)

        """
        #!/bin/bash

        export SINGULARITY_TMPDIR=${params.SINGULARITY_TMPDIR}
        export SLURM_NTASKS=${params.BEAMCON_NTASKS}

	    srun -n ${params.BEAMCON_NTASKS} singularity exec --bind ${params.SCRATCH_ROOT}:${params.SCRATCH_ROOT} \
            ${container} \
            beamcon_3D ${image_cube} \
            --mode total \
            --suffix ${params.BEAMCON_3D_SUFFIX} \
            --bmaj ${params.BMAJ} --bmin ${params.BMIN} --bpa ${params.BPA} \
            -v
        """
}

process get_cube_conv {
    executor = 'local'

    input:
        val image_cube
        val suffix
        val check

    output:
        val cube_conv, emit: cube_conv

    exec:
        cube = file(image_cube)
        cube_conv = file("${cube.getParent()}/${cube.getBaseName()}*${suffix}*${cube.getExtension()}").first()
}

// ----------------------------------------------------------------------------------------
// Workflow
// ----------------------------------------------------------------------------------------

workflow conv2d {
    take:
        image_cube
        stokes

    main:
        beamcon_setup()
        nan_to_zero(image_cube)
        beamcon_2D(nan_to_zero.out.image_cube_zeros, beamcon_setup.out.container)
        get_cube_conv(image_cube, "${params.BEAMCON_2D_SUFFIX}", beamcon_2D.out.stdout)

    emit:
        cube_conv = get_cube_conv.out.cube_conv
}

workflow conv3d {
    take:
        cube
        evaluation_files
        stokes

    main:
        beamcon_setup()
        extract_beamlog(evaluation_files)
        copy_beamlog(cube, evaluation_files, extract_beamlog.out.stdout)
        beamcon_3D(cube, copy_beamlog.out.beamlog, beamcon_setup.out.container)
        get_cube_conv(cube, "${params.BEAMCON_3D_SUFFIX}", beamcon_3D.out.stdout)

    emit:
        cube_conv = get_cube_conv.out.cube_conv
}

// ----------------------------------------------------------------------------------------
