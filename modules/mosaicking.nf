#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

// ----------------------------------------------------------------------------------------
// Processes
// ----------------------------------------------------------------------------------------

// Check
process mosaicking_check {
    executor = 'local'

    input:
        val cubes
        val weights

    output:
        stdout emit: stdout

    exec:
        if (cubes.size() != weights.size()) {
            throw new Exception("Number of healpix pixel files and weights files are not the same")
        }
}

process get_pixel_id {
    input:
        val cubes
        val weights

    output:
        stdout emit: obs_id

    script:
        """
        #!/usr/bin/env python3

        cube_files = [c.rsplit('/', 1)[1] for c in '$cubes'.split(' ')]
        weights_files = [w.rsplit('/', 1)[1] for w in '$weights'.split(' ')]
        cube_pixel_ids = [c.split('.')[0].split('-')[-1] for c in cube_files]
        weight_pixel_ids = [w.split('.')[0].split('-')[-1] for w in weights_files]
        ids = cube_pixel_ids + weight_pixel_ids

        if all(id == ids[0] for id in ids):
            print(ids[0], end='')
        else:
            raise Exception("Not all healpix pixel IDs are the same for input image and weight cubes.")
        """
}

// Generate configuration
process update_linmos_config {
    container = params.MOSAICKING_COMPONENTS_IMAGE
    containerOptions = "--bind ${params.SCRATCH_ROOT}:${params.SCRATCH_ROOT}"

    input:
        val obs_id
        val cubes
        val weights
        val stokes
        val check

    output:
        val "${params.WORKDIR}/${params.HPX_TILE_OUTPUT_DIR}/$obs_id-$stokes-linmos.config", emit: linmos_config

    script:
        """
        python3 -u /app/update_linmos_config.py \
            -c ${params.LINMOS_CONFIG_TEMPLATE} \
            -o ${params.WORKDIR}/${params.HPX_TILE_OUTPUT_DIR}/$obs_id-$stokes-linmos.config \
            --linmos.names "$cubes" \
            --linmos.weights "$weights" \
            --linmos.outname "${params.WORKDIR}/${params.HPX_TILE_OUTPUT_DIR}/$obs_id-$stokes" \
            --linmos.outweight "${params.WORKDIR}/${params.HPX_TILE_OUTPUT_DIR}/weights.$obs_id-$stokes"
        """
}

// Linear mosaicking
process linmos {
    input:
        val obs_id
        val stokes
        val linmos_config

    output:
        val "${params.WORKDIR}/${params.HPX_TILE_OUTPUT_DIR}/$obs_id-$stokes", emit: mosaic
        val "${params.WORKDIR}/${params.HPX_TILE_OUTPUT_DIR}/weights.$obs_id-$stokes", emit: mosaic_weights

    script:
        """
        #!/bin/bash

        singularity pull ${params.SINGULARITY_CACHEDIR}/csirocass_yandasoft.img ${params.LINMOS_IMAGE}
        mpiexec -np 1 singularity exec \
            --bind ${params.SCRATCH_ROOT}:${params.SCRATCH_ROOT} \
            ${params.SINGULARITY_CACHEDIR}/csirocass_yandasoft.img \
            linmos-mpi -c $linmos_config
        """
}

// ----------------------------------------------------------------------------------------
// Workflow
// ----------------------------------------------------------------------------------------

workflow mosaicking {
    take:
        tiles
        weights
        stokes

    main:
        mosaicking_check(tiles, weights)
        get_pixel_id(tiles.collect(), weights.collect())
        update_linmos_config(
            get_pixel_id.out.obs_id,
            tiles.collect(),
            weights.collect(),
            stokes,
            mosaicking_check.out.stdout
        )
        linmos(
            get_pixel_id.out.obs_id,
            stokes,
            update_linmos_config.out.linmos_config
        )

    emit:
        mosaic = linmos.out.mosaic
        weights = linmos.out.mosaic_weights
}

// ----------------------------------------------------------------------------------------