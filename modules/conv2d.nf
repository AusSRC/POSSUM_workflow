#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

// ----------------------------------------------------------------------------------------
// Processes
// ----------------------------------------------------------------------------------------

process get_beam {
    container = params.METADATA_IMAGE
    containerOptions = "--bind ${params.SCRATCH_ROOT}:${params.SCRATCH_ROOT}"

    input:
        val image_cube
        val weights_cube

    output:
        val image_cube, emit: image_cube
        val weights_cube, emit: weights_cube

    script:
        """
        #!python3

        from astropy.io import fits
        with fits.open("$image_cube", mode="readonly") as hdu_img:
            with fits.open("$weights_cube", mode="update") as hdu_w:
                hdr_img = hdu_img[0].header
                hdr_w = hdu_w[0].header
                hdr_w["BMAJ"] = hdr_img["BMAJ"]
                hdr_w["BMIN"] = hdr_img["BMIN"]
                hdr_w["BPA"] = hdr_img["BPA"]
        """
}

// This is required for the beamcon "robust" method.
process nan_to_zero_image {
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

// This is required for the beamcon "robust" method.
process nan_to_zero_weights {
    container = params.METADATA_IMAGE
    containerOptions = "--bind ${params.SCRATCH_ROOT}:${params.SCRATCH_ROOT}"

    input:
        val weights_cube

    output:
        val weights_cube_zeros, emit: weights_cube_zeros

    script:
        filename = file(weights_cube)
        weights_cube_zeros = "${filename.getParent()}/${filename.getBaseName()}.zeros.${filename.getExtension()}"

        """
        #!python3

        import numpy as np
        from astropy.io import fits

        with fits.open("$weights_cube", mode="readonly") as hdu:
            header = hdu[0].header
            data = np.nan_to_num(hdu[0].data)
            header['HISTORY'] = 'Replace NaN with zero'
        hdu = fits.PrimaryHDU(data=data, header=header)
        hdul = fits.HDUList([hdu])
        hdul.writeto("$weights_cube_zeros", overwrite=True)
        """
}

process beamcon_2D_image {
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

process beamcon_2D_weights {
    containerOptions = "${params.BEAMCON_CLUSTER_OPTIONS}"

    input:
        val weights

    output:
        stdout emit: stdout

    script:
        file = file(weights)
        """

        #!/bin/bash

        export SINGULARITY_TMPDIR=${params.SINGULARITY_TMPDIR}
        export SLURM_NTASKS=${params.BEAMCON_NTASKS}

	    srun -n ${params.BEAMCON_NTASKS} singularity exec --bind ${params.SCRATCH_ROOT}:${params.SCRATCH_ROOT} \
            ${params.SINGULARITY_CACHEDIR}/racstools_latest.sif \
            beamcon_2D ${weights} \
            --suffix ${params.BEAMCON_2D_SUFFIX} \
            --bmaj ${params.BMAJ} --bmin ${params.BMIN} --bpa ${params.BPA} \
            -v
        """
}

process get_conv_image_cube {
    executor = 'local'

    input:
        val image_cube
        val check

    output:
        val conv_image_cube, emit: conv_image_cube

    exec:
        image_cube_file = file(image_cube)
        parent = image_cube_file.getParent()
        basename = image_cube_file.getBaseName()
        extension = image_cube_file.getExtension()
        conv_image_cube = file("${parent}/${basename}*${params.BEAMCON_2D_SUFFIX}*${extension}").first()
}

process get_conv_weights_cube {
    executor = 'local'

    input:
        val weights_cube
        val check

    output:
        val conv_weights_cube, emit: conv_weights_cube

    exec:
        weights_cube_file = file(weights_cube)
        parent = weights_cube_file.getParent()
        basename = weights_cube_file.getBaseName()
        extension = weights_cube_file.getExtension()
        conv_weights_cube = file("${parent}/${basename}*${params.BEAMCON_2D_SUFFIX}*${extension}").first()
}

// ----------------------------------------------------------------------------------------
// Workflow
// ----------------------------------------------------------------------------------------

workflow conv2d {
    take:
        image_cube
        weights_cube

    main:
        get_beam(image_cube, weights_cube)
        nan_to_zero_image(image_cube)
        nan_to_zero_weights(weights_cube)
        beamcon_2D_image(nan_to_zero_image.out.image_cube_zeros)
        beamcon_2D_weights(nan_to_zero_weights.out.weights_cube_zeros)
        get_conv_image_cube(image_cube, beamcon_2D_image.out.stdout)
        get_conv_weights_cube(weights_cube, beamcon_2D_weights.out.stdout)

    emit:
        cube_conv = get_conv_image_cube.out.conv_image_cube
        weights_conv = get_conv_weights_cube.out.conv_weights_cube
}

// ----------------------------------------------------------------------------------------
