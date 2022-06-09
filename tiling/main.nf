#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

// ----------------------------------------------------------------------------------------
// Processes
// ----------------------------------------------------------------------------------------

// Check output and header directories exist and are empty
process tiling_pre_check {
    input:
        val image_cube
        val polarisation

    output:
        stdout emit: stdout

    script:
        """
        #!/bin/bash

        # Check image cube exists
        [ ! -f ${image_cube} ] && { echo "Image cube file not found"; exit 1; }

        # Check output and header directories exist
        [ ! -d ${params.WORKDIR}/${params.RUN_NAME}/${params.TILING_HEADER_DIRECTORY} ] && mkdir ${params.WORKDIR}/${params.RUN_NAME}/${params.TILING_HEADER_DIRECTORY}
        [ ! -d ${params.WORKDIR}/${params.RUN_NAME}/${params.REPROJECTION_OUTPUT_DIRECTORY} ] && mkdir ${params.WORKDIR}/${params.RUN_NAME}/${params.REPROJECTION_OUTPUT_DIRECTORY}

        # Check polarisation specific directories exist
        [ ! -d ${params.WORKDIR}/${params.RUN_NAME}/${params.TILING_HEADER_DIRECTORY}/${polarisation} ] && mkdir ${params.WORKDIR}/${params.RUN_NAME}/${params.TILING_HEADER_DIRECTORY}/${polarisation}
        [ ! -d ${params.WORKDIR}/${params.RUN_NAME}/${params.REPROJECTION_OUTPUT_DIRECTORY}/${polarisation} ] && mkdir ${params.WORKDIR}/${params.RUN_NAME}/${params.REPROJECTION_OUTPUT_DIRECTORY}/${polarisation}

        exit 0
        """
}

// Tiling
process generate_healpix_headers {
    container = params.HEALPIX_HEADER_IMAGE
    containerOptions = "--bind ${params.SCRATCH_ROOT}:${params.SCRATCH_ROOT}"

    input:
        val image_cube
        val tiling_pre_check
        val polarisation

    output:
        stdout emit: stdout

    script:
        """
        python3 -u /app/healpix_headers.py \
            -i ${image_cube} \
            -o ${params.WORKDIR}/${params.RUN_NAME}/${params.TILING_HEADER_DIRECTORY}/${polarisation} \
            -n ${params.NSIDE}
        """
}

// Get generated image cube files into channel
process get_healpix_header_files {
    executor = 'local'

    input:
        val generate_healpix_headers
        val polarisation

    output:
        val header_files, emit: header_files

    exec:
        header_files = file("${params.WORKDIR}/${params.RUN_NAME}/${params.TILING_HEADER_DIRECTORY}/${polarisation}/*.hdr")
}

process tile_output_filename {
    input:
        val image_cube
        val header
    
    output:
        val header, emit: header
        stdout emit: tile_filename

    script:
        """
        #!python3

        image_prefix = "$image_cube".rsplit('.', 1)[0]
        tile_id = "$header".rsplit('.', 1)[0]
        tile_filename = f"{image_prefix}_{tile_id}.fits"
        print(tile_filename, end='')
        """
}

// Montage for reprojection
process montage {
    errorStrategy 'ignore'
    container = params.MONTAGE_IMAGE
    containerOptions = "--bind ${params.SCRATCH_ROOT}:${params.SCRATCH_ROOT}"

    input:
        val image_cube
        val header
        val tile_filename
        val polarisation

    output:
        stdout emit: stdout

    script:
        """
        #!/bin/bash

        mProjectCube ${image_cube} ${params.WORKDIR}/${params.RUN_NAME}/${params.REPROJECTION_OUTPUT_DIRECTORY}/${polarisation}/${tile_filename} ${header}
        """
}

// ----------------------------------------------------------------------------------------
// Workflow
// ----------------------------------------------------------------------------------------

workflow tiling {
    take: image_cube
    take: polarisation

    main:
        tiling_pre_check(image_cube, polarisation)
        generate_healpix_headers(image_cube, tiling_pre_check.out.stdout, polarisation)
        get_healpix_header_files(generate_healpix_headers.out.stdout, polarisation)
        tile_output_filename(image_cube, get_healpix_header_files.out.header_files.flatten())
        montage(image_cube, tile_output_filename.out.header, tile_output_filename.out.tile_filename, polarisation)
}

// ----------------------------------------------------------------------------------------
