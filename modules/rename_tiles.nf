#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

// ----------------------------------------------------------------------------------------
// Processes
// ----------------------------------------------------------------------------------------

process generate_tile_name {
    container = params.HPX_TILING_IMAGE
    containerOptions = "--bind ${params.SCRATCH_ROOT}:${params.SCRATCH_ROOT}"

    input:
        val image_cube
        val tile_id

    output:
        stdout emit: filename

    script:
        """
        python3 -u /app/rename_tiles.py \
            -i $image_cube \
            -pf ${params.HPX_TILE_PREFIX} \
            -c ${params.CENTRAL_FREQUENCY} \
            -id $tile_id \
            -v ${params.TILE_NAME_VERSION_NUMBER}
        """
}

process update_image_weights_name {
    executor = 'local'

    input:
        val filename
        val image_cube
        val weights_cube

    output:
        val output_image_cube, emit: output_image_cube
        val output_weights_cube, emit: output_weights_cube

    script:
        def path = file(image_cube).getParent()
        output_image_cube = "${path}/${filename}"
        output_weights_cube = "${path}/weights.${filename}"

        """
        #!/bin/bash

        mv $image_cube $output_image_cube
        mv $weights_cube $output_weights_cube
        """
}

// ----------------------------------------------------------------------------------------
// Workflow
// ----------------------------------------------------------------------------------------

workflow rename_tiles {
    take:
        tile_id
        image_cube
        weights_cube

    main:
        generate_tile_name(image_cube, tile_id)
        update_image_weights_name(
            generate_tile_name.out.filename,
            image_cube,
            weights_cube
        )

    emit:
        image_cube = update_image_weights_name.out.output_image_cube
        weights_cube = update_image_weights_name.out.output_weights_cube
}

// ----------------------------------------------------------------------------------------
