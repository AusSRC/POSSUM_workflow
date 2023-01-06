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

process beamcon_2D {
    containerOptions = "${params.BEAMCON_CLUSTER_OPTIONS}"

    input:
        val image

    output:
        stdout emit: stdout

    script:
        file = file(image)

        """
        #!/bin/bash

        export SINGULARITY_TMPDIR=${params.SINGULARITY_TMPDIR}
        export SLURM_NTASKS=${params.BEAMCON_NTASKS}

	    srun -n ${params.BEAMCON_NTASKS} singularity exec --bind ${params.SCRATCH_ROOT}:${params.SCRATCH_ROOT} \
            ${params.SINGULARITY_CACHEDIR}/racstools_latest.sif \
            beamcon_2D ${image} \
            --bmaj ${params.BMAJ} --bmin ${params.BMIN} --bpa ${params.BPA} \
            -v
        """
}

process get_cube_conv {
    executor = 'local'

    input:
        val image_cube
        val check

    output:
        val cube_conv, emit: cube_conv

    exec:
        image_cube_file = file(image_cube)
        parent = image_cube_file.getParent()
        basename = image_cube_file.getBaseName()
        extension = image_cube_file.getExtension()
        cube_conv = file("${parent}/${basename}*${params.BEAMCON_2D_SUFFIX}*${extension}").first()
}

// ----------------------------------------------------------------------------------------
// Workflow
// ----------------------------------------------------------------------------------------

workflow conv2d {
    take:
        image_cube
        stokes

    main:
        nan_to_zero(image_cube)
        beamcon_2D(nan_to_zero.out.image_cube_zeros)
        get_cube_conv(image_cube, beamcon_2D.out.stdout)

    emit:
        cube_conv = get_cube_conv.out.cube_conv
}

// ----------------------------------------------------------------------------------------
