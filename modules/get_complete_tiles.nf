#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

// ----------------------------------------------------------------------------------------
// Processes
// ----------------------------------------------------------------------------------------

// Find complete tiles
process get_hpx_tiles {
    container = params.HPX_TILING_IMAGE
    containerOptions = "--bind ${params.SCRATCH_ROOT}:${params.SCRATCH_ROOT}"

    input:
        val stokes

    output:
        stdout emit: stdout

    script:
        """
        python3 -u /app/tile_components.py \
            -f "${params.WORKDIR}/${params.TILE_COMPONENT_OUTPUT_DIR}/$stokes" \
            -m "${params.HPX_TILE_MAP}"
        """
}

// Create channel from complete tile output
process parse_complete_hpx_tiles_output {
    executor = 'local'

    input:
        val hpx_pixel_list

    output:
        val tiles, emit: tiles

    exec:
        tiles = Eval.me(hpx_pixel_list)
}

// ----------------------------------------------------------------------------------------
// Workflow
// ----------------------------------------------------------------------------------------

workflow get_complete_tiles {
    take:
        stokes

    main:
        get_hpx_tiles(stokes)
        parse_complete_hpx_tiles_output(get_hpx_tiles.out.stdout.flatten())

    emit:
        tiles = parse_complete_hpx_tiles_output.out.tiles
}

// ----------------------------------------------------------------------------------------