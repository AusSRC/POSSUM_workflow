#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

// ----------------------------------------------------------------------------------------
// Processes
// ----------------------------------------------------------------------------------------

process check {
    input:
        val sbid
        val image_cube

    output:
        val true, emit: done

    script:
        """
        #!/bin/bash

        # Check important files
        [ ! -f $image_cube ] && { echo "Image cube file does not exist"; exit 1; }
        [ ! -f ${params.HPX_TILE_CONFIG_BAND1} ] && { echo "HEALPIX tiling configuration file for band 1 does not exist"; exit 1; }
        [ ! -f ${params.HPX_TILE_CONFIG_BAND2} ] && { echo "HEALPIX tiling configuration file for band 2 does not exist"; exit 1; }

        # Check working directories
        [ ! -d ${params.WORKDIR}/sbid_processing/$sbid ] && mkdir -p ${params.WORKDIR}/sbid_processing/$sbid
        [ ! -d ${params.WORKDIR}/${params.TILE_COMPONENT_OUTPUT_DIR} ] && mkdir -p ${params.WORKDIR}/${params.TILE_COMPONENT_OUTPUT_DIR}

        exit 0
        """
}

process get_obs_id {
    input:
        val image_cube
        val ready

    output:
        val obs_id, emit: obs_id

    exec:
        filename = file(image_cube).getBaseName()
        (_, _, obs_id, _) = (filename =~ /(\S*)_(\d{4}-\d{2}[AB]?)(\S*)$/)[0]
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
        python3 /app/get_file_in_compressed_folder.py \
            -p $evaluation_files \
            -f calibration-metadata-processing-logs \
            -k metadata/footprintOutput \
            -o $evaluation_files/metadata
        """
}

process select_hpx_tile_config {
    executor = 'local'

    input:
        val ready
        val band

    output:
        val hpx_tile_config, emit: hpx_tile_config

    exec:
        hpx_tile_config = null
        int band_value = band as Integer
        if (band_value == 2) {
            hpx_tile_config = "${params.HPX_TILE_CONFIG_BAND2}"
        } else {
            hpx_tile_config = "${params.HPX_TILE_CONFIG_BAND1}"
        }
}

process generate_tile_map {
    container = params.HPX_TILING_IMAGE
    containerOptions = "--bind ${params.SCRATCH_ROOT}:${params.SCRATCH_ROOT}"

    input:
        val footprint_file
        val hpx_tile_config
        val obs_id

    output:
        val true, emit: done

    script:
        """
        python3 /app/generate_tile_pixel_map.py \
            -f $footprint_file \
            -i $obs_id \
            -o "${params.WORKDIR}/sbid_processing/${params.SBID}" \
            -j $hpx_tile_config \
            -r
        """
}

// ----------------------------------------------------------------------------------------
// Workflows
// ----------------------------------------------------------------------------------------

workflow hpx_tile_map {
    take:
        sbid
        image_cube
        evaluation_files
        band

    main:
        check(sbid, image_cube)
        get_footprint_file(evaluation_files)
        get_obs_id(image_cube, check.out.done)
        select_hpx_tile_config(get_obs_id.out.obs_id, band)
        generate_tile_map(
            get_footprint_file.out.stdout,
            select_hpx_tile_config.out.hpx_tile_config,
            get_obs_id.out.obs_id
        )

    emit:
        obs_id = get_obs_id.out.obs_id
        tile_map = file("${params.WORKDIR}/sbid_processing/$sbid/*.csv").first()
}

// ----------------------------------------------------------------------------------------
