#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

// ----------------------------------------------------------------------------------------
// Processes
// ----------------------------------------------------------------------------------------

// Check output and header directories exist and are empty
process tiling_pre_check {
    input:
        val cube

    output:
        stdout emit: stdout

    script:
        """
        #!/bin/bash

        # Check image cube exists
        [ ! -f ${cube} ] && { echo "Image cube file not found"; exit 1; }

        # Check output and header directories exist
        [ ! -d ${params.WORKDIR}/${params.RUN_NAME}/${params.TILING_HEADER_DIRECTORY} ] && mkdir ${params.WORKDIR}/${params.RUN_NAME}/${params.TILING_HEADER_DIRECTORY}
        [ ! -d ${params.WORKDIR}/${params.RUN_NAME}/${params.REPROJECTION_OUTPUT_DIRECTORY} ] && mkdir ${params.WORKDIR}/${params.RUN_NAME}/${params.REPROJECTION_OUTPUT_DIRECTORY}

        # Clear headers if any exist
        rm ${params.WORKDIR}/${params.RUN_NAME}/${params.TILING_HEADER_DIRECTORY}/*
        """
}

// Tiling
process generate_healpix_headers {
    container = params.POSSUM_TILING_COMPONENT
    containerOptions = "--bind ${params.SCRATCH_ROOT}:${params.SCRATCH_ROOT}"

    input:
        val image_cube
        val tiling_pre_check

    output:
        stdout emit: stdout

    script:
        """
        python3 -u /app/healpix_headers.py \
            -i ${image_cube} \
            -o ${params.WORKDIR}/${params.RUN_NAME}/${params.TILING_HEADER_DIRECTORY} \
            -n ${params.NSIDE}
        """
}

// Get generated image cube files into channel
process get_healpix_header_files {
    executor = 'local'

    input:
        val generate_healpix_headers

    output:
        val header_files, emit: header_files

    exec:
        header_files = file("${params.WORKDIR}/${params.TILING_HEADER_DIRECTORY}/*.hdr")
}

// Montage for reprojection
process montage {
    errorStrategy 'ignore'
    container = params.MONTAGE_IMAGE
    containerOptions = "--bind ${params.SCRATCH_ROOT}:${params.SCRATCH_ROOT}"

    input:
        val image_cube
        val header

    output:
        stdout emit: stdout

    script:
        """
        #!/bin/bash

        mProjectCube ${image_cube} ${params.WORKDIR}/${pa${params.RUN_NAME}/rams.REPROJECTION_OUTPUT_DIRECTORY}/test.reprojected.fits ${header}
        """
}

// ----------------------------------------------------------------------------------------
// Workflow
// ----------------------------------------------------------------------------------------

workflow tiling {
    take: image_cube

    main:
        tiling_pre_check()
        generate_healpix_headers(image_cube, tiling_pre_check.out.stdout)
        get_healpix_header_files(generate_healpix_headers.out.stdout)
        montage(image_cube, get_healpix_header_files.out.header_files.flatten())

    // TODO(austin): emit output cube
}

// ----------------------------------------------------------------------------------------
