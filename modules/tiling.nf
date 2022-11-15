#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

// ----------------------------------------------------------------------------------------
// Processes
// ----------------------------------------------------------------------------------------

process tiling_pre_check {
    input:
        val sbid
        val image_cube
        val stokes

    output:
        stdout emit: stdout

    script:
        """
        #!/bin/bash

        # Check image_cube file
        [ ! -f $image_cube ] && { echo "Image cube file does not exist"; exit 1; }

        # Check working directories
        [ ! -d ${params.WORKDIR}/$sbid ] && mkdir -p ${params.WORKDIR}/$sbid
        [ ! -d ${params.WORKDIR}/${params.TILE_COMPONENT_OUTPUT_DIR} ] && mkdir -p ${params.WORKDIR}/${params.TILE_COMPONENT_OUTPUT_DIR}
        [ ! -d ${params.WORKDIR}/${params.TILE_COMPONENT_OUTPUT_DIR}/$stokes ] && mkdir -p ${params.WORKDIR}/${params.TILE_COMPONENT_OUTPUT_DIR}/$stokes

        # Check tiling config files
        [ ! -f ${params.HPX_TILE_CONFIG} ] && { echo "HEALPIX tiling configuration file does not exist"; exit 1; }

        exit 0
        """
}

process get_footprint_file {
    container = params.METADATA_IMAGE
    containerOptions = "--bind ${params.SCRATCH_ROOT}:${params.SCRATCH_ROOT}"

    input:
        val evaluation_files

    output:
        stdout emit: stdout

    script:
        """
        python3 /app/get_footprint_files.py -f $evaluation_files
        """
}

process generate_tile_map {
    container = params.HPX_TILING_IMAGE
    containerOptions = "--bind ${params.SCRATCH_ROOT}:${params.SCRATCH_ROOT}"

    input:
        val footprint_file
        val extract_check

    output:
        stdout emit: stdout

    script:
        """
        python3 /app/generate_tile_pixel_map.py \
            -f "${params.WORKDIR}/${params.SBID}/${params.EVALUATION_FILES_DIR}/$footprint_file" \
            -o "${params.WORKDIR}/${params.SBID}" \
            -j "${params.HPX_TILE_CONFIG}"
        """
}

process get_tile_pixel_map_csv {
    executor = 'local'

    input:
        val check

    output:
        val pixel_map_csv, emit: pixel_map_csv

    exec:
        pixel_map_csv = file("${params.WORKDIR}/${params.SBID}/*.csv")
}

process run_hpx_tiling {
    container = params.HPX_TILING_IMAGE
    containerOptions = "--bind ${params.SCRATCH_ROOT}:${params.SCRATCH_ROOT}"

    input:
        val obs_id
        val image_cube
        val pixel_map_csv
        val stokes

    output:
        stdout emit: stdout

    script:
        """
        python3 -u /app/casa_tiling.py \
            -i "$obs_id" \
            -c "$image_cube" \
            -m "$pixel_map_csv" \
            -o "${params.WORKDIR}/${params.TILE_COMPONENT_OUTPUT_DIR}/$stokes" \
            -t "${params.HPX_TILE_TEMPLATE}"
        """
}

// ----------------------------------------------------------------------------------------
// Workflow
// ----------------------------------------------------------------------------------------

workflow tiling {
    take:
        sbid
        image_cube
        stokes
        evaluation_files
        metadata_dir

    main:
        tiling_pre_check(sbid, image_cube, stokes)
        get_footprint_file(evaluation_files)
        generate_tile_map(get_footprint_file.out.stdout, metadata_dir)
        get_tile_pixel_map_csv(generate_tile_map.out.stdout)
        run_hpx_tiling(
            generate_tile_map.out.stdout,
            image_cube,
            get_tile_pixel_map_csv.out.pixel_map_csv.flatten(),
            stokes
        )

    emit:
        obs_id = generate_tile_map.out.stdout
}

// ----------------------------------------------------------------------------------------
