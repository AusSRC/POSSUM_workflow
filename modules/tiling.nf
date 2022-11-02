#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

// ----------------------------------------------------------------------------------------
// Processes
// ----------------------------------------------------------------------------------------

process tiling_pre_check {
    input:
        val sbid
        val image_cube

    output:
        stdout emit: stdout

    script:
        """
        #!/bin/bash

        # Check image_cube file
        [ ! -f $image_cube ] && { echo "Image cube file does not exist"; exit 1; }

        # Check working directories
        [ ! -d ${params.WORKDIR}/$sbid ] && mkdir -p ${params.WORKDIR}/$sbid
        [ ! -d ${params.WORKDIR}/$sbid/${params.TILING_OUTPUT_DIR} ] && mkdir -p ${params.WORKDIR}/$sbid/${params.TILING_OUTPUT_DIR}
        [ ! -d ${params.WORKDIR}/$sbid/${params.EVALUATION_FILES_DIR} ] && mkdir -p ${params.WORKDIR}/$sbid/${params.EVALUATION_FILES_DIR}

        # Check tiling config files
        [ ! -f ${params.HPX_TILE_MAP_CONFIG} ] && { echo "HEALPIX tiling map configuration file does not exist"; exit 1; }
        [ ! -f ${params.TILING_CONFIG} ] && { echo "Tiling configuration file does not exist"; exit 1; }

        exit 0
        """
}

process download_evaluation_files {
    container = params.METADATA_IMAGE
    containerOptions = "--bind ${params.SCRATCH_ROOT}:${params.SCRATCH_ROOT}"

    input:
        val check

    output:
        val "${params.WORKDIR}/${params.SBID}/${params.EVALUATION_FILES_DIR}", emit: evaluation_files

    script:
        """
        python3 /app/download_evaluation_files.py \
            -s ${params.SBID} \
            -p AS103 \
            -o ${params.WORKDIR}/${params.SBID}/${params.EVALUATION_FILES_DIR} \
            -c ${params.CASDA_CREDENTIALS}
        """
}

process extract_metadata {
    input:
        val check

    output:
        stdout emit: stdout

    script:
        """
        #!/usr/bin/python3
        import os
        import glob

        files = glob.glob("${params.WORKDIR}/${params.SBID}/${params.EVALUATION_FILES_DIR}/" + "*metadata*.tar")
        for f in files:
            os.system(f"tar -xvf {f} -C ${params.WORKDIR}/${params.SBID}/${params.EVALUATION_FILES_DIR}")
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
            -o "${params.WORKDIR}/${params.SBID}/${params.TILING_OUTPUT_DIR}/POSSUM" \
            -j "${params.HPX_TILE_MAP_CONFIG}"
        """
}

process get_tile_pixel_map_csv {
    executor = 'local'

    input:
        val check

    output:
        val pixel_map_csv, emit: pixel_map_csv

    exec:
        pixel_map_csv = file("${params.WORKDIR}/${params.SBID}/${params.TILING_OUTPUT_DIR}/POSSUM*.csv")
}

process run_hpx_tiling {
    container = params.HPX_TILING_IMAGE
    containerOptions = "--bind ${params.SCRATCH_ROOT}:${params.SCRATCH_ROOT}"

    input:
        val image_cube
        val pixel_map_csv

    output:
        stdout emit: stdout

    script:
        """
        python3 -u /app/casa_tiling.py \
            -i "$image_cube" \
            -m "$pixel_map_csv" \
            -o "${params.WORKDIR}/${params.SBID}/${params.TILING_OUTPUT_DIR}/" \
            -j "${params.TILING_CONFIG}"
        """
}

// ----------------------------------------------------------------------------------------
// Workflow
// ----------------------------------------------------------------------------------------

workflow tiling {
    take:
        sbid
        image_cube

    main:
        tiling_pre_check(sbid, image_cube)
        download_evaluation_files(tiling_pre_check.out.stdout)
        extract_metadata(download_evaluation_files.out.evaluation_files)
        get_footprint_file(download_evaluation_files.out.evaluation_files)
        generate_tile_map(get_footprint_file.out.stdout, extract_metadata.out.stdout)
        get_tile_pixel_map_csv(generate_tile_map.out.stdout)
        run_hpx_tiling(image_cube, get_tile_pixel_map_csv.out.pixel_map_csv.flatten())
}

// ----------------------------------------------------------------------------------------

workflow {
    sbid = "${params.SBID}"
    image_cube = "${params.IMAGE_CUBE}"

    main:
        tiling(sbid, image_cube)
}