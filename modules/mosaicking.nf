#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

// ----------------------------------------------------------------------------------------
// Processes
// ----------------------------------------------------------------------------------------

process linmos_setup {
    output:
        stdout emit: stdout
        val container, emit: container

    script:
        container = file("${params.SINGULARITY_CACHEDIR}/csirocass_yandasoft.img")

        """
        #!/bin/bash

        # check image exists
        [ ! -f ${container} ] && { singularity pull ${container} ${params.LINMOS_IMAGE}; }

        # check output directories
        [ ! -d ${params.WORKDIR}/${params.HPX_TILE_OUTPUT_DIR} ] && mkdir -p ${params.WORKDIR}/${params.HPX_TILE_OUTPUT_DIR}
        [ ! -d ${params.WORKDIR}/${params.HPX_TILE_OUTPUT_DIR}/${params.LINMOS_CONFIG_SUBDIR} ] && mkdir -p ${params.WORKDIR}/${params.HPX_TILE_OUTPUT_DIR}/${params.LINMOS_CONFIG_SUBDIR}

        exit 0
        """
}

process get_files {
    executor = 'local'

    input:
        val tile_id
        val image_cube_map
        val weights_cube_map
        val check

    output:
        val image_cubes, emit: image_cubes
        val weights_cubes, emit: weights_cubes

    exec:
        image_cubes = "[${image_cube_map[tile_id].join(',').replace('.fits', '')}]"
        weights_cubes = "[${weights_cube_map[tile_id].join(',').replace('.fits', '')}]"
}

// Generate configuration
process update_linmos_config {
    container = params.MOSAICKING_COMPONENTS_IMAGE
    containerOptions = "--bind ${params.SCRATCH_ROOT}:${params.SCRATCH_ROOT}"

    input:
        val tile_id
        val image_cubes
        val weights_cubes
        val stokes

    output:
        val "${params.WORKDIR}/${params.HPX_TILE_OUTPUT_DIR}/${params.LINMOS_CONFIG_SUBDIR}/${params.HPX_TILE_PREFIX}.${tile_id}.${stokes}.linmos.config", emit: linmos_config

    script:
        """
        python3 -u /app/update_linmos_config.py \
            -c ${params.LINMOS_CONFIG_TEMPLATE} \
            -o ${params.WORKDIR}/${params.HPX_TILE_OUTPUT_DIR}/${params.LINMOS_CONFIG_SUBDIR}/${params.HPX_TILE_PREFIX}.${tile_id}.${stokes}.linmos.config \
            --linmos.names "$image_cubes" \
            --linmos.weights "$weights_cubes" \
            --linmos.outname "${params.WORKDIR}/${params.HPX_TILE_OUTPUT_DIR}/${params.HPX_TILE_PREFIX}.${tile_id}.${stokes}" \
            --linmos.outweight "${params.WORKDIR}/${params.HPX_TILE_OUTPUT_DIR}/weights.${params.HPX_TILE_PREFIX}.${tile_id}.${stokes}"
        """
}

// Linear mosaicking
process linmos {
    input:
        val tile_id
        val stokes
        val linmos_config
        val container

    output:
        val "${params.WORKDIR}/${params.HPX_TILE_OUTPUT_DIR}/${params.HPX_TILE_PREFIX}.${tile_id}.${stokes}.fits", emit: mosaic
        val "${params.WORKDIR}/${params.HPX_TILE_OUTPUT_DIR}/weights.${params.HPX_TILE_PREFIX}.${tile_id}.${stokes}.fits", emit: mosaic_weights

    script:
        """
        #!/bin/bash

        mpiexec -np 1 singularity exec \
            --bind ${params.SCRATCH_ROOT}:${params.SCRATCH_ROOT} \
            $container \
            linmos-mpi -c $linmos_config
        """
}

// ----------------------------------------------------------------------------------------
// Workflow
// ----------------------------------------------------------------------------------------

workflow mosaicking {
    take:
        tile_id
        image_cube_map
        weights_cube_map
        stokes

    main:
        linmos_setup()
        get_files(tile_id, image_cube_map, weights_cube_map, linmos_setup.out.stdout)
        update_linmos_config(tile_id, get_files.out.image_cubes, get_files.out.weights_cubes, stokes)
        linmos(tile_id, stokes, update_linmos_config.out.linmos_config, linmos_setup.out.container)

    emit:
        tile_id
        mosaic = linmos.out.mosaic
        mosaic_weights = linmos.out.mosaic_weights
}

// ----------------------------------------------------------------------------------------