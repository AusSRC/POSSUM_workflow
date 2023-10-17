#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

// ----------------------------------------------------------------------------------------
// Processes
// ----------------------------------------------------------------------------------------

process check {
    executor = 'local'

    input:
        val sbid
        val image_cube

    output:
        stdout emit: stdout

    script:
        """
        #!/bin/bash

        # Check important files
        [ ! -f $image_cube ] && { echo "Image cube file does not exist"; exit 1; }
        [ ! -f ${params.HPX_TILE_CONFIG} ] && { echo "HEALPIX tiling configuration file does not exist"; exit 1; }

        # Check working directories
        [ ! -d ${params.WORKDIR}/$sbid ] && mkdir -p ${params.WORKDIR}/$sbid
        [ ! -d ${params.WORKDIR}/${params.TILE_COMPONENT_OUTPUT_DIR} ] && mkdir -p ${params.WORKDIR}/${params.TILE_COMPONENT_OUTPUT_DIR}

        exit 0
        """
}

process get_obs_id {
    executor = 'local'

    input:
        val image_cube

    output:
        val obs_id, emit: obs_id

    exec:
        filename = file(image_cube).getBaseName()
        (_, _, obs_id, _) = (filename =~ /(\S*)_(\d{4}-\d{2}[AB]?)(\S*)$/)[0]
}

// This method was required for earlier SBIDs e.g. 9992
process get_obs_id_from_footprint_file {
    executor = 'local'

    input:
        val footprint_file

    output:
        val obs_id, emit: obs_id

    exec:
        filename = file(footprint_file).getBaseName()
        (_, _, obs_id, _) = (filename =~ /(\S*)_(\d{4}-\d{2}[AB]?)(\S*)$/)[0]
}

process get_footprint_file {
    executor = 'local'

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
            -k metadata/footprintOutput \
            -o $evaluation_files/metadata
        """
}

process generate_tile_map {
    executor = 'local'

    container = params.HPX_TILING_IMAGE
    containerOptions = "--bind ${params.SCRATCH_ROOT}:${params.SCRATCH_ROOT}"

    input:
        val footprint_file
        val obs_id

    output:
        stdout emit: stdout

    script:
        """
        python3 /app/generate_tile_pixel_map.py \
            -f $footprint_file \
            -i $obs_id \
            -o "${params.WORKDIR}/${params.SBID}" \
            -j "${params.HPX_TILE_CONFIG}"
        """
}

process get_tile_map {
    executor = 'local'

    input:
        val check

    output:
        val pixel_map_csv, emit: pixel_map_csv

    exec:
        pixel_map_csv = file("${params.WORKDIR}/${params.SBID}/*.csv").first()
}

// ----------------------------------------------------------------------------------------
// Workflows
// ----------------------------------------------------------------------------------------

workflow hpx_tile_map {
    take:
        sbid
        image_cube
        evaluation_files

    main:
        check(sbid, image_cube)
        get_footprint_file(evaluation_files)
        get_obs_id_from_footprint_file(get_footprint_file.out.stdout)
        generate_tile_map(get_footprint_file.out.stdout, get_obs_id_from_footprint_file.out.obs_id)
        get_tile_map(generate_tile_map.out.stdout)

    emit:
        obs_id = get_obs_id_from_footprint_file.out.obs_id
        tile_map = get_tile_map.out.pixel_map_csv
}

// ----------------------------------------------------------------------------------------
